package main

import (
    "bytes"
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "io/fs"
    "os"
    "os/exec"
    "path/filepath"
    "runtime"
    "sort"
    "strconv"
    "strings"
    "time"

    "github.com/charmbracelet/bubbles/help"
    "github.com/charmbracelet/bubbles/key"
    "github.com/charmbracelet/bubbles/list"
    "github.com/charmbracelet/bubbles/spinner"
    "github.com/charmbracelet/bubbles/textinput"
    "github.com/charmbracelet/bubbles/viewport"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

// ---------- Files and data ----------

type fileItem struct{
    path     string
    isDir    bool
    selected bool
}
func (i fileItem) Title() string       { return filepath.Base(i.path) }
func (i fileItem) Description() string {
    prefix := "[ ]"
    if i.selected { prefix = "[x]" }
    if i.isDir { return prefix + " " + i.path + " — dir" }
    return prefix + " " + i.path
}
func (i fileItem) FilterValue() string { return i.path }

func collectPaths(args []string, capCount int) ([]fileItem, error) {
	if len(args) == 0 { args = []string{"."} }
	items := make([]fileItem, 0, 256)
	seen := 0
	push := func(p string, d bool){
		items = append(items, fileItem{path: p, isDir: d}); seen++
	}
	for _, p := range args {
		fi, err := os.Stat(p)
		if err != nil { continue }
		if fi.IsDir() {
            filepath.WalkDir(p, func(path string, d fs.DirEntry, err error) error {
				if err != nil { return nil }
				if d.IsDir() { return nil }
                push(path, false)
				if capCount > 0 && seen >= capCount { return errors.New("cap") }
				return nil
			})
		} else {
			push(p, false)
		}
		if capCount > 0 && seen >= capCount { break }
	}
	return items, nil
}

// scanDir lists immediate children of a directory (files and directories)
func scanDir(dir string) []fileItem {
    entries, err := os.ReadDir(dir)
    if err != nil { return nil }
    items := make([]fileItem, 0, len(entries))
    for _, e := range entries {
        p := filepath.Join(dir, e.Name())
        items = append(items, fileItem{ path: p, isDir: e.IsDir() })
    }
    return items
}

// ---------- Commands ----------

func which(cmd string) string {
	if p, err := exec.LookPath(cmd); err == nil { return p }
	return ""
}

func finfoCmd() []string {
    if p := which("finfo"); p != "" { return []string{p} }
    // Try CWD and parent
    if _, err := os.Stat("./finfo.zsh"); err == nil { return []string{"./finfo.zsh"} }
    if _, err := os.Stat("../finfo.zsh"); err == nil { return []string{"../finfo.zsh"} }
    // Try relative to executable dir
    if exe, err := os.Executable(); err == nil {
        exeDir := filepath.Dir(exe)
        cand1 := filepath.Join(exeDir, "finfo.zsh")
        if _, err := os.Stat(cand1); err == nil { return []string{cand1} }
        cand2 := filepath.Join(exeDir, "..", "finfo.zsh")
        if _, err := os.Stat(cand2); err == nil { return []string{cand2} }
    }
	return []string{"finfo"}
}

func finfoPreviewArgs(target string, long bool) []string {
    // Prefer JSON to allow structured, concise preview; include brief/long hint
    args := finfoCmd()
    if long { args = append(args, "--long") } else { args = append(args, "--brief") }
    args = append(args, "--json", "--", target)
    return args
}

func finfoPrettyArgs(target string, long bool) []string {
    args := finfoCmd()
    if long { args = append(args, "--long") } else { args = append(args, "--brief") }
    args = append(args, "--", target)
    return args
}

func runCmdTimeout(ctx context.Context, name string, args ...string) (string, error) {
	c := exec.CommandContext(ctx, name, args...)
	var out bytes.Buffer
	c.Stdout = &out
	c.Stderr = &out
	if err := c.Run(); err != nil { return out.String(), err }
	return out.String(), nil
}

func openPath(p string) {
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		cmd = exec.Command("open", p)
	} else {
		if which("xdg-open") != "" { cmd = exec.Command("xdg-open", p) }
	}
	if cmd != nil { _ = cmd.Start() }
}

func revealPath(p string) {
	if runtime.GOOS == "darwin" { _ = exec.Command("open", "-R", p).Start() }
}

func copyPath(p string) {
	if runtime.GOOS == "darwin" && which("pbcopy") != "" {
        cmd := exec.Command("pbcopy"); stdin, _ := cmd.StdinPipe(); _ = cmd.Start(); _, _ = stdin.Write([]byte(p)); _ = stdin.Close(); _ = cmd.Wait(); return
	}
	if which("wl-copy") != "" { _ = exec.Command("wl-copy", p).Run(); return }
	if which("xclip") != "" { _ = exec.Command("sh", "-c", fmt.Sprintf("printf '%%s' %q | xclip -selection clipboard", p)).Run(); return }
}

func clearQuarantine(p string) {
	if runtime.GOOS == "darwin" && which("xattr") != "" { _ = exec.Command("xattr", "-d", "com.apple.quarantine", p).Run() }
}

func chmodPath(p, oct string) error {
	return exec.Command("chmod", oct, p).Run()
}

func moveToTrash(p string) error {
    if runtime.GOOS == "darwin" {
        if which("osascript") != "" {
            // AppleScript move to trash
            return exec.Command("osascript", "-e", fmt.Sprintf("tell application \"Finder\" to delete POSIX file \"%s\"", p)).Run()
        }
        // Fallback: move to ~/.Trash (best-effort, no overwrite)
        home, _ := os.UserHomeDir()
        dst := filepath.Join(home, ".Trash", filepath.Base(p))
        return os.Rename(p, dst)
    }
    // Linux: try gio or trash-cli if available
    if which("gio") != "" { return exec.Command("gio", "trash", p).Run() }
    if which("trash-put") != "" { return exec.Command("trash-put", p).Run() }
    return os.Remove(p)
}

// ---------- JSON preview ----------

type finfoJSON struct {
    Name string `json:"name"`
    Path struct{ Abs string `json:"abs"`; Rel string `json:"rel"` } `json:"path"`
    Size struct{ Bytes int64 `json:"bytes"`; Human string `json:"human"` } `json:"size"`
    Type struct{ Description string `json:"description"` } `json:"type"`
    Security struct{ Verdict string `json:"verdict"` } `json:"security"`
}

// ---------- UI ----------

type keymap struct {
    Up, Down, Enter, Back, Quit, ToggleLong, TogglePreview, Actions, Copy, Open, Reveal, Chmod, ClearQ, Refresh, Help, Filter, Select, SelectAll, ClearSel, Undo, JobLog key.Binding
    PagePrev, PageNext, Jump1, Jump2, Jump3, Jump4, Jump5, Jump6, JumpTop, JumpBottom key.Binding
    DirPrevPage, DirNextPage key.Binding
}

// Implement help.KeyMap
func (k keymap) ShortHelp() []key.Binding {
    return []key.Binding{k.Up, k.Down, k.Actions, k.Help, k.Quit}
}

func (k keymap) FullHelp() [][]key.Binding {
    return [][]key.Binding{
        {k.Up, k.Down, k.Filter},
        {k.ToggleLong, k.TogglePreview, k.Open, k.Reveal},
        {k.Chmod, k.ClearQ, k.Refresh},
        {k.Select, k.SelectAll, k.ClearSel, k.Undo},
        {k.JobLog, k.Actions, k.Back},
        {k.Help, k.Quit},
    }
}

func defaultKeymap() keymap {
	return keymap{
		Up:         key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
		Down:       key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
        Enter:      key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "into dir")),
        Back:       key.NewBinding(key.WithKeys("backspace", "left", "h"), key.WithHelp("⌫/←/h", "back")),
		Quit:       key.NewBinding(key.WithKeys("q", "esc", "ctrl+c"), key.WithHelp("q", "quit")),
		ToggleLong: key.NewBinding(key.WithKeys("l"), key.WithHelp("l", "toggle long")),
        TogglePreview: key.NewBinding(key.WithKeys("p"), key.WithHelp("p", "toggle preview")),
		Actions:    key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "actions")),
		Copy:       key.NewBinding(key.WithKeys("c"), key.WithHelp("c", "copy path")),
		Open:       key.NewBinding(key.WithKeys("o"), key.WithHelp("o", "open")),
		Reveal:     key.NewBinding(key.WithKeys("E"), key.WithHelp("E", "reveal")),
		Chmod:      key.NewBinding(key.WithKeys("m"), key.WithHelp("m", "chmod")),
		ClearQ:     key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "clear quarantine")),
		Refresh:    key.NewBinding(key.WithKeys("R"), key.WithHelp("R", "refresh")),
		Help:       key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
		Filter:     key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "filter")),
        Select:     key.NewBinding(key.WithKeys(" "), key.WithHelp("space", "select")),
        SelectAll:  key.NewBinding(key.WithKeys("A"), key.WithHelp("A", "select all")),
        ClearSel:   key.NewBinding(key.WithKeys("V"), key.WithHelp("V", "clear selection")),
        Undo:       key.NewBinding(key.WithKeys("U"), key.WithHelp("U", "undo last")),
        JobLog:     key.NewBinding(key.WithKeys("J"), key.WithHelp("J", "job log")),
        PagePrev:   key.NewBinding(key.WithKeys("["), key.WithHelp("[", "prev page")),
        PageNext:   key.NewBinding(key.WithKeys("]"), key.WithHelp("]", "next page")),
        DirPrevPage: key.NewBinding(key.WithKeys("<"), key.WithHelp("<", "prev dir page")),
        DirNextPage: key.NewBinding(key.WithKeys(">"), key.WithHelp(">", "next dir page")),
        Jump1:      key.NewBinding(key.WithKeys("1"), key.WithHelp("1", "Hdr")),
        Jump2:      key.NewBinding(key.WithKeys("2"), key.WithHelp("2", "Ess")),
        Jump3:      key.NewBinding(key.WithKeys("3"), key.WithHelp("3", "Time")),
        Jump4:      key.NewBinding(key.WithKeys("4"), key.WithHelp("4", "Paths")),
        Jump5:      key.NewBinding(key.WithKeys("5"), key.WithHelp("5", "Sec")),
        Jump6:      key.NewBinding(key.WithKeys("6"), key.WithHelp("6", "Acts")),
        JumpTop:    key.NewBinding(key.WithKeys("g"), key.WithHelp("g", "top")),
        JumpBottom: key.NewBinding(key.WithKeys("$"), key.WithHelp("$", "bottom")),
	}
}

type mode int
const (
	modeList mode = iota
	modeDetail
	modeChmod
    modeActions
    modeConfirm
    modeHelp
    modeOpenWith
    modeMoveToDir
    modeRenamePattern
    modeOpsPreview
)

type previewMsg struct{ seq int; out string; err string }

type model struct {
	list    list.Model
	preview viewport.Model
	help    help.Model
	keys    keymap
	filter  textinput.Model
	status  string
	long    bool
	mode    mode
    actions list.Model
    jobs    jobs
    spin    spinner.Model
    theme   theme
    originalArgs []string
    lastPreviewRaw string
    pendingAct action
    pendingOps []op
    pendingDir string
    opsOverlay viewport.Model
    opsOverlayText string
    jobLog []string
    showJobLog bool
    undo []executedOp
    // Navigation
    browsing bool
    cwd string
    dirStack []string
    // Preview
    showPreview bool
    // Preview async
    previewSeq int
    previewTimeout time.Duration
    previewDelay time.Duration
    // Large dir management
    dirAll []fileItem
    dirCap int
    listPage int
    // Modes
    singleFile bool
    lastRendered string
}

type executedOp struct {
    act action
    from string
    to   string
    reversible bool
    at time.Time
}

func (m *model) pushUndo(op executedOp) {
    m.undo = append(m.undo, op)
    if len(m.undo) > 100 { m.undo = m.undo[len(m.undo)-100:] }
}

type jobs struct {
    running int
    done    int
    failed  int
}

type theme struct {
    title lipgloss.Style
    status lipgloss.Style
    overlay lipgloss.Style
}

func defaultTheme() theme {
    return theme{
        title:  lipgloss.NewStyle().Foreground(lipgloss.Color("63")).Bold(true),
        status: lipgloss.NewStyle().Faint(true),
        overlay: lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(1, 2),
    }
}

func themeFromEnv() theme {
    name := os.Getenv("FINFOTUI_THEME")
    if name == "" { return defaultTheme() }
    t := defaultTheme()
    switch strings.ToLower(name) {
    case "mono", "plain":
        t.title = lipgloss.NewStyle().Bold(true)
        t.status = lipgloss.NewStyle()
        t.overlay = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).Padding(1, 2)
    case "nord":
        t.title = lipgloss.NewStyle().Foreground(lipgloss.Color("110")).Bold(true)
        t.status = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
        t.overlay = lipgloss.NewStyle().BorderForeground(lipgloss.Color("110")).Border(lipgloss.RoundedBorder()).Padding(1, 2)
    case "dracula":
        t.title = lipgloss.NewStyle().Foreground(lipgloss.Color("171")).Bold(true)
        t.status = lipgloss.NewStyle().Foreground(lipgloss.Color("244"))
        t.overlay = lipgloss.NewStyle().BorderForeground(lipgloss.Color("171")).Border(lipgloss.RoundedBorder()).Padding(1, 2)
    }
    return t
}

// ---------- Actions ----------

type action int

const (
    actOpen action = iota
    actReveal
    actCopy
    actClearQ
    actChmod
    actOpenWith
    actCopyJSON
    actTrash
    actMoveToDir
    actRenamePattern
    actUndo
)

type actionItem struct {
    name string
    kind action
}

func (a actionItem) Title() string       { return a.name }
func (a actionItem) Description() string { return "" }
func (a actionItem) FilterValue() string { return a.name }
func (m *model) refreshActions() {
    items := make([]list.Item, 0, 12)
    // Always available
    items = append(items, actionItem{name: "Copy path(s)", kind: actCopy})
    items = append(items, actionItem{name: "Open", kind: actOpen})
    if runtime.GOOS == "darwin" {
        items = append(items, actionItem{name: "Reveal (macOS)", kind: actReveal})
        items = append(items, actionItem{name: "Open with… (macOS)", kind: actOpenWith})
        items = append(items, actionItem{name: "Clear quarantine (macOS)", kind: actClearQ})
    }
    items = append(items, actionItem{name: "Change permissions (chmod)", kind: actChmod})
    // Multi-select and file-only actions
    sel := m.targetItems()
    // Move/Rename only when all selections are files (not dirs)
    allFiles := true
    for _, it := range sel { if it.isDir { allFiles = false; break } }
    if len(sel) > 0 && allFiles {
        items = append(items, actionItem{name: "Move to directory…", kind: actMoveToDir})
        items = append(items, actionItem{name: "Rename by pattern…", kind: actRenamePattern})
    }
    // Trash allowed for any selection
    if len(sel) > 0 { items = append(items, actionItem{name: "Move to Trash", kind: actTrash}) }
    // Utilities
    items = append(items, actionItem{name: "Copy JSON (preview)", kind: actCopyJSON})
    if len(m.undo) > 0 { items = append(items, actionItem{name: "Undo last", kind: actUndo}) }
    m.actions.SetItems(items)
}

type op struct{ from, to string }

func initialModelFromArgs(args []string) model {
    items, _ := collectPaths(args, 5000)
    l := list.New([]list.Item{}, list.NewDefaultDelegate(), 0, 0)
	li := make([]list.Item, len(items))
	for i := range items { li[i] = items[i] }
	l.SetItems(li)
	l.Title = "Files"
	l.SetShowStatusBar(false)
	l.SetShowHelp(false)
	l.SetFilteringEnabled(true)
    pv := viewport.Model{ Width: 0, Height: 0 }
	pv.YPosition = 0
    in := textinput.New(); in.Placeholder = "filter"; in.Prompt = "/ "; in.CharLimit = 256; in.Blur()
    acts := list.New([]list.Item{}, list.NewDefaultDelegate(), 0, 0)
    sp := spinner.New()
    sp.Spinner = spinner.Points
    th := themeFromEnv()
    ov := viewport.Model{ Width: 0, Height: 0 }
    timeoutMs := 1500
    if v := os.Getenv("FINFOTUI_PREVIEW_MS"); v != "" {
        if n, err := strconv.Atoi(v); err == nil && n > 100 { timeoutMs = n }
    }
    delayMs := 120
    if v := os.Getenv("FINFOTUI_PREVIEW_DELAY_MS"); v != "" {
        if n, err := strconv.Atoi(v); err == nil && n >= 0 { delayMs = n }
    }
    m := model{ list: l, preview: pv, help: help.New(), keys: defaultKeymap(), filter: in, long: true, mode: modeList, actions: acts, spin: sp, theme: th, originalArgs: append([]string{}, args...), opsOverlay: ov, showPreview: true, previewTimeout: time.Duration(timeoutMs) * time.Millisecond, previewDelay: time.Duration(delayMs) * time.Millisecond, dirCap: 5000 }
    // Enable directory-browsing mode when a single argument is a directory
    if len(args) == 1 {
        if fi, err := os.Stat(args[0]); err == nil && fi.IsDir() {
            m.browsing = true
            m.cwd = args[0]
            items := scanDir(m.cwd)
            sort.Slice(items, func(i,j int) bool { if items[i].isDir != items[j].isDir { return items[i].isDir } ; return strings.ToLower(filepath.Base(items[i].path)) < strings.ToLower(filepath.Base(items[j].path)) })
            m.dirAll = items
            m.listPage = 0
            m.rebuildDirPage()
        } else if err == nil && !fi.IsDir() {
            m.singleFile = true
            // Seed list with the file so preview can load immediately
            l.SetItems([]list.Item{fileItem{path: args[0], isDir: false}})
        }
    }
    return m
}

func (m model) Init() tea.Cmd {
    // When single-file, seed preview immediately even if list is empty
    if m.singleFile && len(m.list.Items()) == 0 && len(m.originalArgs) == 1 {
        // create a synthetic list with the file so preview works
        if fi, err := os.Stat(m.originalArgs[0]); err == nil {
            it := fileItem{path: m.originalArgs[0], isDir: fi.IsDir()}
            m.list.SetItems([]list.Item{it})
        }
    }
    return tea.Batch(m.loadPreview(), m.spin.Tick)
}

func (m model) loadPreview() tea.Cmd {
    if !m.showPreview || len(m.list.Items()) == 0 { return nil }
	it, ok := m.list.SelectedItem().(fileItem)
	if !ok { return nil }
    // No explicit cancel func retained; sequence guard prevents stale updates
    args := finfoPreviewArgs(it.path, m.long)
    seq := m.previewSeq + 1
    m.previewSeq = seq
	return func() tea.Msg {
        ctx, cancel := context.WithTimeout(context.Background(), m.previewTimeout)
        // store cancel so next call can cancel in-flight
        // Note: model is captured immutably; we pass seq to validate latest
        out, err := runCmdTimeout(ctx, args[0], args[1:]...)
        cancel()
        emsg := ""
        if err != nil { emsg = err.Error() }
        return previewMsg{seq: seq, out: out, err: emsg}
	}
}

func (m model) reloadList() tea.Cmd {
    prevSel := make(map[string]bool, 32)
    for i := 0; i < len(m.list.Items()); i++ {
        if it, ok := m.list.Items()[i].(fileItem); ok && it.selected { prevSel[it.path] = true }
    }
    if m.browsing {
        cwd := m.cwd
        return func() tea.Msg {
            items := scanDir(cwd)
            sort.Slice(items, func(i,j int) bool { if items[i].isDir != items[j].isDir { return items[i].isDir } ; return strings.ToLower(filepath.Base(items[i].path)) < strings.ToLower(filepath.Base(items[j].path)) })
            for i := range items { items[i].selected = prevSel[items[i].path] }
            return listDirMsg{items: items}
        }
    }
    args := m.originalArgs
    return func() tea.Msg {
        items, _ := collectPaths(args, 5000)
        li := make([]list.Item, len(items))
        for i := range items { items[i].selected = prevSel[items[i].path]; li[i] = items[i] }
        // Return a closure to update list on main thread
        return func() tea.Msg { return listMsg{items: li} }
    }
}

type listMsg struct{ items []list.Item }
type listDirMsg struct{ items []fileItem }

func (m *model) rebuildDirPage() {
    if !m.browsing { return }
    total := len(m.dirAll)
    if m.dirCap <= 0 { m.dirCap = 2000 }
    pages := (total + m.dirCap - 1) / m.dirCap
    if pages < 1 { pages = 1 }
    if m.listPage >= pages { m.listPage = pages - 1 }
    if m.listPage < 0 { m.listPage = 0 }
    start := m.listPage * m.dirCap
    end := start + m.dirCap
    if end > total { end = total }
    window := m.dirAll[start:end]
    li := make([]list.Item, len(window))
    for i := range window { li[i] = window[i] }
    m.list.SetItems(li)
}

// Helper: determine target items (selected ones if any, otherwise current)
func (m model) targetItems() []fileItem {
    selected := make([]fileItem, 0, 8)
    for i := 0; i < len(m.list.Items()); i++ {
        if it, ok := m.list.Items()[i].(fileItem); ok && it.selected { selected = append(selected, it) }
    }
    if len(selected) > 0 { return selected }
    if it, ok := m.list.SelectedItem().(fileItem); ok { return []fileItem{it} }
    return nil
}

// Jobs messages
type jobDoneMsg struct{ path string; act action; err error }

func (m model) runActionOnTargets(act action) tea.Cmd {
    targets := m.targetItems()
    if len(targets) == 0 { return nil }
    cmds := make([]tea.Cmd, 0, len(targets))
    mstatus := ""
    switch act {
    case actCopy:
        // Copy all paths as newline-joined (single job)
        paths := make([]string, 0, len(targets))
        for _, t := range targets { paths = append(paths, t.path) }
        return func() tea.Msg {
            copyPathsJoined(paths)
            return jobDoneMsg{path: strings.Join(paths, ", "), act: act, err: nil}
        }
    case actOpen:
        for _, t := range targets {
            p := t.path
            cmds = append(cmds, func() tea.Msg {
                openPath(p)
                return jobDoneMsg{path: p, act: act, err: nil}
            })
        }
        mstatus = "opening"
    case actReveal:
        for _, t := range targets {
            p := t.path
            cmds = append(cmds, func() tea.Msg {
                revealPath(p)
                return jobDoneMsg{path: p, act: act, err: nil}
            })
        }
        mstatus = "revealing"
    case actClearQ:
        for _, t := range targets {
            p := t.path
            cmds = append(cmds, func() tea.Msg {
                clearQuarantine(p)
                return jobDoneMsg{path: p, act: act, err: nil}
            })
        }
        mstatus = "clearing quarantine"
    case actTrash:
        for _, t := range targets {
            p := t.path
            cmds = append(cmds, func() tea.Msg {
                err := moveToTrash(p)
                return jobDoneMsg{path: p, act: act, err: err}
            })
        }
        mstatus = "trashing"
    }
    if mstatus != "" { /* no-op, status updated by caller */ }
    return tea.Batch(cmds...)
}

func copyPathsJoined(paths []string) {
    joined := strings.Join(paths, "\n")
    if runtime.GOOS == "darwin" && which("pbcopy") != "" {
        cmd := exec.Command("pbcopy"); stdin, _ := cmd.StdinPipe(); _ = cmd.Start(); _, _ = stdin.Write([]byte(joined)); _ = stdin.Close(); _ = cmd.Wait(); return
    }
    if which("wl-copy") != "" { _ = exec.Command("wl-copy", joined).Run(); return }
    if which("xclip") != "" { _ = exec.Command("sh", "-c", fmt.Sprintf("printf '%%s' %q | xclip -selection clipboard", joined)).Run(); return }
}

// Undo execution
func (m model) runUndo() tea.Cmd {
    if len(m.undo) == 0 { m.status = "nothing to undo"; return nil }
    last := m.undo[len(m.undo)-1]
    m.undo = m.undo[:len(m.undo)-1]
    if !last.reversible { m.status = "cannot undo"; return nil }
    from := last.from; to := last.to
    m.jobs.running++
    return func() tea.Msg {
        err := os.Rename(from, to)
        return jobDoneMsg{path: from + " -> " + to, act: actUndo, err: err}
    }
}

func openWithPath(app, p string) {
    if runtime.GOOS == "darwin" {
        _ = exec.Command("open", "-a", app, p).Start()
    } else {
        openPath(p)
    }
}

func copyText(s string) {
    if runtime.GOOS == "darwin" && which("pbcopy") != "" {
        cmd := exec.Command("pbcopy"); stdin, _ := cmd.StdinPipe(); _ = cmd.Start(); _, _ = stdin.Write([]byte(s)); _ = stdin.Close(); _ = cmd.Wait(); return
    }
    if which("wl-copy") != "" { _ = exec.Command("wl-copy", s).Run(); return }
    if which("xclip") != "" { _ = exec.Command("sh", "-c", fmt.Sprintf("printf '%%s' %q | xclip -selection clipboard", s)).Run(); return }
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Layout: left list 40%, right preview 60%
        if m.singleFile {
            m.preview.Width = msg.Width - 2
            m.preview.Height = msg.Height - 4
            return m, nil
        }
        lw := int(float64(msg.Width) * 0.45)
		if lw < 30 { lw = 30 }
        pw := msg.Width - lw - 1
		lh := msg.Height - 2
		ph := msg.Height - 2
		m.list.SetSize(lw, lh)
        m.preview.Width = pw; m.preview.Height = ph
        m.actions.SetSize(msg.Width/2, msg.Height/2)
        m.opsOverlay.Width = msg.Width - 6
        m.opsOverlay.Height = msg.Height - 8
    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spin, cmd = m.spin.Update(msg)
        return m, cmd
    case previewMsg:
        if msg.seq != m.previewSeq { return m, nil }
        // If debounce tick (empty out), now run the real preview load
        if msg.out == "" { return m, m.loadPreview() }
        // Try parse JSON, fallback to raw text
        var fj finfoJSON
        s := msg.out
        m.lastPreviewRaw = s
        if err := json.Unmarshal([]byte(s), &fj); err == nil && fj.Name != "" {
            b := &strings.Builder{}
            fmt.Fprintf(b, "%s\n", lipgloss.NewStyle().Bold(true).Render(fj.Name))
            fmt.Fprintf(b, "Type: %s\n", fj.Type.Description)
            fmt.Fprintf(b, "Size: %s (%d B)\n", fj.Size.Human, fj.Size.Bytes)
            if fj.Security.Verdict != "" { fmt.Fprintf(b, "Verdict: %s\n", fj.Security.Verdict) }
            fmt.Fprintf(b, "Rel: %s\nAbs: %s\n", fj.Path.Rel, fj.Path.Abs)
            m.preview.SetContent(b.String())
        } else {
            // If JSON failed, try pretty output for a faithful static preview
            it, _ := m.list.SelectedItem().(fileItem)
            args := finfoPrettyArgs(it.path, m.long)
            ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second); defer cancel()
            out, _ := runCmdTimeout(ctx, args[0], args[1:]...)
            if strings.TrimSpace(out) != "" { m.preview.SetContent(out) } else { m.preview.SetContent(s) }
        }
        if msg.err != "" {
            m.status = "preview error: " + msg.err
        } else {
            m.status = ""
        }
    case listMsg:
        m.list.SetItems(msg.items)
        return m, m.loadPreview()
    case jobDoneMsg:
        m.jobs.running--
        if msg.err != nil { m.jobs.failed++ } else { m.jobs.done++ }
        switch msg.act {
        case actCopy: m.status = "copied" 
        case actOpen: m.status = "opened" 
        case actReveal: m.status = "revealed"
        case actClearQ: m.status = "quarantine cleared"
        case actMoveToDir: m.status = "moved"
        case actRenamePattern: m.status = "renamed"
        case actTrash: m.status = "trashed"
        case actUndo: m.status = "undone"
        }
        return m, nil
	case tea.KeyMsg:
        // Global toggle for help overlay
        if key.Matches(msg, m.keys.Help) {
            if m.mode == modeHelp { m.mode = modeList } else { m.mode = modeHelp }
            return m, nil
        }
        if m.mode == modeHelp {
            if msg.Type == tea.KeyEsc || msg.String() == "q" || msg.String() == "?" {
                m.mode = modeList
            }
            return m, nil
        }
        if m.mode == modeActions {
            // Keep action list gated to current context
            m.refreshActions()
            switch {
            case msg.Type == tea.KeyEsc:
                m.mode = modeList
                return m, nil
            case msg.Type == tea.KeyEnter:
                if it, ok := m.actions.SelectedItem().(actionItem); ok {
                    switch it.kind {
                    case actClearQ:
                        m.mode = modeConfirm
                        m.status = fmt.Sprintf("confirm clear quarantine for %d item(s)? y/N", len(m.targetItems()))
                        return m, nil
                    case actChmod:
                        m.mode = modeChmod; m.filter.Placeholder = "octal (e.g. 644)"; m.filter.SetValue(""); m.filter.Focus(); return m, nil
                    case actOpenWith:
                        m.mode = modeOpenWith; m.filter.Placeholder = "app name (e.g. Preview)"; m.filter.SetValue(""); m.filter.Focus(); return m, nil
                    case actCopyJSON:
                        if m.lastPreviewRaw != "" { copyText(m.lastPreviewRaw); m.status = "JSON copied" }
                        m.mode = modeList; return m, nil
                    case actTrash:
                        m.mode = modeConfirm
                        m.pendingAct = actTrash
                        m.status = fmt.Sprintf("confirm move to Trash for %d item(s)? y/N", len(m.targetItems()))
                        return m, nil
                    case actMoveToDir:
                        m.mode = modeMoveToDir; m.filter.Placeholder = "destination directory"; m.filter.SetValue(""); m.filter.Focus(); return m, nil
                    case actRenamePattern:
                        m.mode = modeRenamePattern; m.filter.Placeholder = "pattern: {name}{ext} or {name}-{n}{ext}"; m.filter.SetValue("{name}{ext}"); m.filter.Focus(); return m, nil
                    case actUndo:
                        // Trigger undo via keybinding or action
                        return m, m.runUndo()
                    default:
                        m.jobs.running += len(m.targetItems())
                        return m, m.runActionOnTargets(it.kind)
                    }
                }
                return m, nil
            default:
                var cmd tea.Cmd
                m.actions, cmd = m.actions.Update(msg)
                return m, cmd
            }
        }
        if m.mode == modeOpsPreview {
            switch msg.Type {
            case tea.KeyEsc:
                m.mode = modeList
                m.pendingAct = 0; m.pendingOps = nil
                return m, nil
            case tea.KeyEnter:
                // Confirm and execute
                if m.pendingAct == actMoveToDir || m.pendingAct == actRenamePattern {
                    ops := m.pendingOps
                    cmds := make([]tea.Cmd, 0, len(ops))
                    for _, op := range ops { from := op.from; to := op.to; cmds = append(cmds, func() tea.Msg { err := os.Rename(from, to); return jobDoneMsg{path: from + " -> " + to, act: m.pendingAct, err: err} }) }
                    m.jobs.running += len(ops)
                    m.pendingOps = nil; m.pendingAct = 0
                    m.mode = modeList
                    return m, tea.Batch(tea.Batch(cmds...), m.reloadList())
                }
                return m, nil
            }
        }
        if m.mode == modeConfirm {
            s := msg.String()
            if s == "y" || s == "Y" {
                m.jobs.running += len(m.targetItems())
                m.mode = modeList
                if m.pendingAct == actTrash {
                    m.pendingAct = 0
                    return m, tea.Batch(m.runActionOnTargets(actTrash), m.reloadList())
            } else if m.pendingAct == actMoveToDir || m.pendingAct == actRenamePattern {
                ops := m.pendingOps
                // Run file operations
                cmds := make([]tea.Cmd, 0, len(ops))
                for _, op := range ops { from := op.from; to := op.to; cmds = append(cmds, func() tea.Msg { err := os.Rename(from, to); return jobDoneMsg{path: from + " -> " + to, act: m.pendingAct, err: err} }) }
                m.pendingOps = nil; m.pendingAct = 0
                return m, tea.Batch(tea.Batch(cmds...), m.reloadList())
                }
                return m, tea.Batch(m.runActionOnTargets(actClearQ), m.loadPreview())
            }
            if s == "n" || s == "N" || msg.Type == tea.KeyEsc {
                m.mode = modeList
                m.status = "cancelled"
            }
            return m, nil
        }
		switch {
		case key.Matches(msg, m.keys.Quit):
			return m, tea.Quit
        case key.Matches(msg, m.keys.Up), key.Matches(msg, m.keys.Down):
            if m.singleFile {
                var cmd tea.Cmd
                m.preview, cmd = m.preview.Update(msg)
                return m, cmd
            }
            var cmd tea.Cmd
            m.list, cmd = m.list.Update(msg)
            // debounce preview to avoid thrash when scrolling
            seq := m.previewSeq + 1
            m.previewSeq = seq
            delayed := tea.Tick(m.previewDelay, func(time.Time) tea.Msg { return previewMsg{seq: seq} })
            return m, tea.Batch(cmd, delayed)
        case key.Matches(msg, m.keys.ToggleLong):
			m.long = !m.long
			return m, m.loadPreview()
        case key.Matches(msg, m.keys.TogglePreview):
            m.showPreview = !m.showPreview
            return m, m.loadPreview()
        // Single-file preview navigation shortcuts
        case key.Matches(msg, m.keys.PagePrev):
            if m.singleFile { m.preview.LineUp(10); return m, nil }
        case key.Matches(msg, m.keys.PageNext):
            if m.singleFile { m.preview.LineDown(10); return m, nil }
        case key.Matches(msg, m.keys.JumpTop):
            if m.singleFile { m.preview.GotoTop(); return m, nil }
        case key.Matches(msg, m.keys.JumpBottom):
            if m.singleFile { m.preview.GotoBottom(); return m, nil }
		case key.Matches(msg, m.keys.Copy):
            targets := m.targetItems()
            if len(targets) == 1 { copyPath(targets[0].path) } else {
                paths := make([]string, 0, len(targets)); for _, t := range targets { paths = append(paths, t.path) }
                copyPathsJoined(paths)
            }
            m.status = "copied"
        case key.Matches(msg, m.keys.Enter):
			if m.browsing {
				if it, ok := m.list.SelectedItem().(fileItem); ok {
					if it.isDir {
						m.dirStack = append(m.dirStack, m.cwd)
						m.cwd = it.path
                        items := scanDir(m.cwd)
                        sort.Slice(items, func(i,j int) bool { if items[i].isDir != items[j].isDir { return items[i].isDir } ; return strings.ToLower(filepath.Base(items[i].path)) < strings.ToLower(filepath.Base(items[j].path)) })
                        m.dirAll = items
                        m.listPage = 0
                        m.rebuildDirPage()
						return m, m.loadPreview()
					}
				}
			}
		case key.Matches(msg, m.keys.Back):
			if m.browsing && len(m.dirStack) > 0 {
				m.cwd = m.dirStack[len(m.dirStack)-1]
				m.dirStack = m.dirStack[:len(m.dirStack)-1]
                items := scanDir(m.cwd)
                sort.Slice(items, func(i,j int) bool { if items[i].isDir != items[j].isDir { return items[i].isDir } ; return strings.ToLower(filepath.Base(items[i].path)) < strings.ToLower(filepath.Base(items[j].path)) })
                m.dirAll = items
                m.listPage = 0
                m.rebuildDirPage()
				return m, m.loadPreview()
			}
		case key.Matches(msg, m.keys.Open):
            m.jobs.running += len(m.targetItems())
            return m, m.runActionOnTargets(actOpen)
		case key.Matches(msg, m.keys.Reveal):
            m.jobs.running += len(m.targetItems())
            return m, m.runActionOnTargets(actReveal)
		case key.Matches(msg, m.keys.ClearQ):
            m.mode = modeConfirm
            m.status = fmt.Sprintf("confirm clear quarantine for %d item(s)? y/N", len(m.targetItems()))
            return m, nil
		case key.Matches(msg, m.keys.Chmod):
			m.mode = modeChmod; m.filter.Placeholder = "octal (e.g. 644)"; m.filter.SetValue(""); m.filter.Focus();
		case key.Matches(msg, m.keys.Filter):
			m.filter.Placeholder = "filter"; m.filter.SetValue(""); m.filter.Focus()
        case key.Matches(msg, m.keys.Refresh):
            // Refresh both preview and file list
            return m, tea.Batch(m.reloadList(), m.loadPreview())
        case key.Matches(msg, m.keys.Select):
            idx := m.list.Index()
            if it, ok := m.list.SelectedItem().(fileItem); ok {
                it.selected = !it.selected
                m.list.SetItem(idx, it)
            }
            return m, nil
        case key.Matches(msg, m.keys.SelectAll):
            for i := 0; i < len(m.list.Items()); i++ { if it, ok := m.list.Items()[i].(fileItem); ok { it.selected = true; m.list.SetItem(i, it) } }
            return m, nil
        case key.Matches(msg, m.keys.ClearSel):
            for i := 0; i < len(m.list.Items()); i++ { if it, ok := m.list.Items()[i].(fileItem); ok { it.selected = false; m.list.SetItem(i, it) } }
            return m, nil
        case key.Matches(msg, m.keys.Actions):
            m.refreshActions()
            m.mode = modeActions
            // Center overlay size is set in WindowSize
            return m, nil
        case key.Matches(msg, m.keys.DirPrevPage):
            if m.browsing && len(m.dirAll) > m.dirCap { m.listPage--; m.rebuildDirPage(); return m, nil }
        case key.Matches(msg, m.keys.DirNextPage):
            if m.browsing && len(m.dirAll) > m.dirCap { m.listPage++; m.rebuildDirPage(); return m, nil }
        case key.Matches(msg, m.keys.JobLog):
            m.showJobLog = !m.showJobLog
            return m, nil
        case key.Matches(msg, m.keys.Undo):
            return m, m.runUndo()
		}
	}
	// If entering input modes
	switch m.mode {
	case modeChmod:
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok {
			s := k.String()
			if s == "enter" {
                oct := strings.TrimSpace(m.filter.Value())
                targets := m.targetItems()
                if len(targets) > 0 {
                    // Run chmod on all targets asynchronously
                    cmds := make([]tea.Cmd, 0, len(targets))
                    for _, t := range targets { p := t.path; cmds = append(cmds, func() tea.Msg { _ = chmodPath(p, oct); return jobDoneMsg{path: p, act: actChmod, err: nil} }) }
                    m.jobs.running += len(targets)
                    m.status = "chmod applied"
                    m.mode = modeList; m.filter.Blur(); return m, tea.Batch(tea.Batch(cmds...), m.loadPreview())
                }
                m.mode = modeList; m.filter.Blur(); return m, nil
			} else if s == "esc" {
				m.mode = modeList; m.filter.Blur()
			}
		}
		return m, cmd
	case modeMoveToDir:
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok {
			s := k.String()
			if s == "enter" {
				dst := strings.TrimSpace(m.filter.Value())
				if dst != "" {
					targets := m.targetItems()
					ops := make([]op, 0, len(targets))
					for i, t := range targets {
						base := filepath.Base(t.path)
						to := filepath.Join(dst, base)
						// ensure unique with (n)
						try := to
						n := 1
						for {
							if _, err := os.Stat(try); os.IsNotExist(err) { break }
							try = filepath.Join(dst, fmt.Sprintf("%s (%d)%s", strings.TrimSuffix(base, filepath.Ext(base)), n, filepath.Ext(base)))
							n++
						}
						ops = append(ops, op{from: t.path, to: try})
						_ = i
					}
					m.pendingOps = ops
					m.pendingAct = actMoveToDir
					// Build dry-run overlay text
					b := &strings.Builder{}
					fmt.Fprintf(b, "Move preview → %s\n\n", dst)
					for _, op := range ops { fmt.Fprintf(b, "%s\n  ↳ %s\n\n", op.from, op.to) }
					m.opsOverlayText = b.String()
					m.opsOverlay.SetContent(m.opsOverlayText)
					m.mode = modeOpsPreview
					m.status = "enter to confirm, esc to cancel"
					return m, nil
				}
				m.mode = modeList; m.filter.Blur(); return m, nil
			} else if s == "esc" {
				m.mode = modeList; m.filter.Blur()
			}
		}
		return m, cmd
	case modeRenamePattern:
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok {
			s := k.String()
			if s == "enter" {
				pat := strings.TrimSpace(m.filter.Value())
				if pat != "" {
					targets := m.targetItems()
					ops := make([]op, 0, len(targets))
					for idx, t := range targets {
						dir := filepath.Dir(t.path)
						bn := filepath.Base(t.path)
						name := strings.TrimSuffix(bn, filepath.Ext(bn))
						ext := filepath.Ext(bn)
						out := pat
						out = strings.ReplaceAll(out, "{name}", name)
						out = strings.ReplaceAll(out, "{ext}", ext)
						out = strings.ReplaceAll(out, "{n}", fmt.Sprintf("%d", idx+1))
						to := filepath.Join(dir, out)
						ops = append(ops, op{from: t.path, to: to})
					}
					m.pendingOps = ops
					m.pendingAct = actRenamePattern
					b := &strings.Builder{}
					fmt.Fprintf(b, "Rename preview\n\n")
					for _, op := range ops { fmt.Fprintf(b, "%s\n  ↳ %s\n\n", op.from, op.to) }
					m.opsOverlayText = b.String()
					m.opsOverlay.SetContent(m.opsOverlayText)
					m.mode = modeOpsPreview
					m.status = "enter to confirm, esc to cancel"
					return m, nil
				}
				m.mode = modeList; m.filter.Blur(); return m, nil
			} else if s == "esc" {
				m.mode = modeList; m.filter.Blur()
			}
		}
		return m, cmd
	case modeOpenWith:
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if k, ok := msg.(tea.KeyMsg); ok {
			s := k.String()
			if s == "enter" {
				app := strings.TrimSpace(m.filter.Value())
				targets := m.targetItems()
				if app != "" && len(targets) > 0 {
					cmds := make([]tea.Cmd, 0, len(targets))
					for _, t := range targets { p := t.path; a := app; cmds = append(cmds, func() tea.Msg { openWithPath(a, p); return jobDoneMsg{path: p, act: actOpenWith, err: nil} }) }
					m.jobs.running += len(targets)
					m.status = "opened with"
					m.mode = modeList; m.filter.Blur(); return m, tea.Batch(tea.Batch(cmds...), m.loadPreview())
				}
				m.mode = modeList; m.filter.Blur(); return m, nil
			} else if s == "esc" {
				m.mode = modeList; m.filter.Blur()
			}
		}
		return m, cmd
	}
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
    title := m.theme.title.Render(" finfo TUI (alpha)")
    if m.singleFile {
        // Minimalist single-file view: just header + preview + help line
        status := m.theme.status.Render(strings.TrimSpace(m.status))
        base := title + "\n" + m.preview.View() + "\n" + m.help.View(m.keys) + "  " + status + "\n"
        return base
    }
    left := m.list.View()
    right := ""
    if m.showPreview { right = m.preview.View() }
    // Build dynamic status
    selCount := 0
    for i := 0; i < len(m.list.Items()); i++ { if it, ok := m.list.Items()[i].(fileItem); ok && it.selected { selCount++ } }
    jobs := fmt.Sprintf("jobs %s %d ▸ ✓%d ✗%d", m.spin.View(), m.jobs.running, m.jobs.done, m.jobs.failed)
    status := m.theme.status.Render(strings.TrimSpace(fmt.Sprintf("%s  |  selected %d  |  %s", m.status, selCount, jobs)))
	// Input line (filter/chmod) when focused
	inputLine := ""
	if m.filter.Focused() {
		inputLine = "\n" + m.filter.View()
	}
    // Footer shows page hint for large dirs
    footer := m.help.View(m.keys) + "  " + status
    if m.browsing {
        total := len(m.dirAll)
        if m.dirCap > 0 && total > m.dirCap {
            pages := (total + m.dirCap - 1) / m.dirCap
            footer += fmt.Sprintf("  |  Page %d/%d (</> to switch)", m.listPage+1, pages)
        }
    }
    base := title + "\n" + lipgloss.JoinHorizontal(lipgloss.Top, left, right) + inputLine + "\n" + footer + "\n"
    if m.mode == modeActions {
        w := lipgloss.Width(base)
        overlay := m.theme.overlay.Render("Actions\n" + m.actions.View() + "\nenter to run, esc to close")
        // simple overlay appended; terminals will show below
        _ = w // placeholder to avoid unused; layout kept simple
        return base + "\n" + overlay
    }
    if m.mode == modeConfirm {
        overlay := m.theme.overlay.Render(m.status)
        return base + "\n" + overlay
    }
    if m.mode == modeHelp {
        b := &strings.Builder{}
        fmt.Fprintf(b, "Keymap\n\n")
        fmt.Fprintf(b, "Navigation: ↑/k, ↓/j, / filter, enter select\n")
        fmt.Fprintf(b, "Actions: a palette, c copy, o open, E reveal, r clear quarantine, m chmod\n")
        fmt.Fprintf(b, "Selection: space toggle, A all, V clear\n")
        fmt.Fprintf(b, "Misc: l toggle long, R refresh, q quit, ? help\n\n")
        fmt.Fprintf(b, "Batch ops apply to selected items; otherwise current item.")
        overlay := m.theme.overlay.Render(b.String())
        return base + "\n" + overlay
    }
    if m.mode == modeOpsPreview {
        overlay := m.theme.overlay.Render(m.opsOverlayText)
        return base + "\n" + overlay
    }
    if m.showJobLog {
        // show last ~20 job logs
        start := 0
        if len(m.jobLog) > 20 { start = len(m.jobLog) - 20 }
        b := &strings.Builder{}
        fmt.Fprintf(b, "Job log (latest)\n\n")
        for i := start; i < len(m.jobLog); i++ { fmt.Fprintf(b, "%s\n", m.jobLog[i]) }
        overlay := m.theme.overlay.Render(b.String())
        return base + "\n" + overlay
    }
    return base
}

func main() {
	paths := os.Args[1:]
	m := initialModelFromArgs(paths)
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		os.Exit(1)
	}
}

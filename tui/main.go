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
    "strings"
    "time"

    "github.com/charmbracelet/bubbles/help"
    "github.com/charmbracelet/bubbles/key"
    "github.com/charmbracelet/bubbles/list"
    "github.com/charmbracelet/bubbles/textinput"
    "github.com/charmbracelet/bubbles/viewport"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

// ---------- Files and data ----------

type fileItem struct{
	path string
	isDir bool
}
func (i fileItem) Title() string       { return filepath.Base(i.path) }
func (i fileItem) Description() string { if i.isDir { return i.path + " — dir" }; return i.path }
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

// ---------- Commands ----------

func which(cmd string) string {
	if p, err := exec.LookPath(cmd); err == nil { return p }
	return ""
}

func finfoCmd() []string {
	if p := which("finfo"); p != "" { return []string{p} }
	if _, err := os.Stat("./finfo.zsh"); err == nil { return []string{"./finfo.zsh"} }
	return []string{"finfo"}
}

func finfoPreviewArgs(target string, long bool) []string {
    // Prefer JSON to allow structured, concise preview; fallback to pretty if JSON fails
    args := append(finfoCmd(), "--json", "--", target)
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
	Up, Down, Enter, Quit, ToggleLong, Actions, Copy, Open, Reveal, Chmod, ClearQ, Refresh, Help, Filter key.Binding
}

func defaultKeymap() keymap {
	return keymap{
		Up:         key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
		Down:       key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
		Enter:      key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "detail")),
		Quit:       key.NewBinding(key.WithKeys("q", "esc", "ctrl+c"), key.WithHelp("q", "quit")),
		ToggleLong: key.NewBinding(key.WithKeys("l"), key.WithHelp("l", "toggle long")),
		Actions:    key.NewBinding(key.WithKeys("a"), key.WithHelp("a", "actions")),
		Copy:       key.NewBinding(key.WithKeys("c"), key.WithHelp("c", "copy path")),
		Open:       key.NewBinding(key.WithKeys("o"), key.WithHelp("o", "open")),
		Reveal:     key.NewBinding(key.WithKeys("E"), key.WithHelp("E", "reveal")),
		Chmod:      key.NewBinding(key.WithKeys("m"), key.WithHelp("m", "chmod")),
		ClearQ:     key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "clear quarantine")),
		Refresh:    key.NewBinding(key.WithKeys("R"), key.WithHelp("R", "refresh")),
		Help:       key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
		Filter:     key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "filter")),
	}
}

type mode int
const (
	modeList mode = iota
	modeDetail
	modeChmod
)

type previewMsg string

type model struct {
	list    list.Model
	preview viewport.Model
	help    help.Model
	keys    keymap
	filter  textinput.Model
	status  string
	long    bool
	mode    mode
}

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
	return model{ list: l, preview: pv, help: help.New(), keys: defaultKeymap(), filter: in, long: true, mode: modeList }
}

func (m model) Init() tea.Cmd {
	return m.loadPreview()
}

func (m model) loadPreview() tea.Cmd {
	if m.list.Len() == 0 { return nil }
	it, ok := m.list.SelectedItem().(fileItem)
	if !ok { return nil }
	args := finfoPreviewArgs(it.path, m.long)
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second); defer cancel()
		out, _ := runCmdTimeout(ctx, args[0], args[1:]...)
		return previewMsg(out)
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Layout: left list 40%, right preview 60%
		lw := int(float64(msg.Width) * 0.4)
		if lw < 30 { lw = 30 }
		pw := msg.Width - lw - 1
		lh := msg.Height - 2
		ph := msg.Height - 2
		m.list.SetSize(lw, lh)
		m.preview.Width = pw; m.preview.Height = ph
    case previewMsg:
        // Try parse JSON, fallback to raw text
        var fj finfoJSON
        s := string(msg)
        if err := json.Unmarshal([]byte(s), &fj); err == nil && fj.Name != "" {
            b := &strings.Builder{}
            fmt.Fprintf(b, "%s\n", lipgloss.NewStyle().Bold(true).Render(fj.Name))
            fmt.Fprintf(b, "Type: %s\n", fj.Type.Description)
            fmt.Fprintf(b, "Size: %s (%d B)\n", fj.Size.Human, fj.Size.Bytes)
            if fj.Security.Verdict != "" { fmt.Fprintf(b, "Verdict: %s\n", fj.Security.Verdict) }
            fmt.Fprintf(b, "Rel: %s\nAbs: %s\n", fj.Path.Rel, fj.Path.Abs)
            m.preview.SetContent(b.String())
        } else {
            m.preview.SetContent(s)
        }
        m.status = ""
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.keys.Quit):
			return m, tea.Quit
		case key.Matches(msg, m.keys.Up), key.Matches(msg, m.keys.Down):
			var cmd tea.Cmd
			m.list, cmd = m.list.Update(msg)
			return m, tea.Batch(cmd, m.loadPreview())
		case key.Matches(msg, m.keys.ToggleLong):
			m.long = !m.long
			return m, m.loadPreview()
		case key.Matches(msg, m.keys.Copy):
			if it, ok := m.list.SelectedItem().(fileItem); ok { copyPath(it.path); m.status = "copied" }
		case key.Matches(msg, m.keys.Open):
			if it, ok := m.list.SelectedItem().(fileItem); ok { openPath(it.path); m.status = "opened" }
		case key.Matches(msg, m.keys.Reveal):
			if it, ok := m.list.SelectedItem().(fileItem); ok { revealPath(it.path); m.status = "revealed" }
		case key.Matches(msg, m.keys.ClearQ):
			if it, ok := m.list.SelectedItem().(fileItem); ok { clearQuarantine(it.path); m.status = "quarantine cleared"; return m, m.loadPreview() }
		case key.Matches(msg, m.keys.Chmod):
			m.mode = modeChmod; m.filter.Placeholder = "octal (e.g. 644)"; m.filter.SetValue(""); m.filter.Focus();
		case key.Matches(msg, m.keys.Filter):
			m.filter.Placeholder = "filter"; m.filter.SetValue(""); m.filter.Focus()
		case key.Matches(msg, m.keys.Refresh):
			return m, m.loadPreview()
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
				if it, ok := m.list.SelectedItem().(fileItem); ok {
					_ = chmodPath(it.path, strings.TrimSpace(m.filter.Value()))
					m.status = "chmod applied"
				}
				m.mode = modeList; m.filter.Blur(); return m, m.loadPreview()
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
	title := lipgloss.NewStyle().Foreground(lipgloss.Color("63")).Bold(true).Render(" finfo TUI (alpha)")
	left := m.list.View()
	right := m.preview.View()
	status := lipgloss.NewStyle().Faint(true).Render(m.status)
	// Input line (filter/chmod) when focused
	inputLine := ""
	if m.filter.Focused() {
		inputLine = "\n" + m.filter.View()
	}
	return title + "\n" + lipgloss.JoinHorizontal(lipgloss.Top, left, right) + inputLine + "\n" + m.help.View(m.keys) + "  " + status + "\n"
}

func main() {
	paths := os.Args[1:]
	m := initialModelFromArgs(paths)
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		os.Exit(1)
	}
}

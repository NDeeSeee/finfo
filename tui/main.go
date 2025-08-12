package main

import (
	"os"
	"path/filepath"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/lipgloss"
)

type item struct{ title, desc string }
func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

type keymap struct {
	Up, Down, Enter, Quit, Refresh key.Binding
}

func defaultKeymap() keymap {
	return keymap{
		Up:      key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
		Down:    key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
		Enter:   key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "view")),
		Quit:    key.NewBinding(key.WithKeys("q", "esc", "ctrl+c"), key.WithHelp("q", "quit")),
		Refresh: key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refresh")),
	}
}

type model struct {
	list   list.Model
	help   help.Model
	keys   keymap
	status string
}

func initialModel(paths []string) model {
	items := []list.Item{}
	for _, p := range paths {
		abs, _ := filepath.Abs(p)
		fi, err := os.Stat(p)
		desc := abs
		if err == nil {
			if fi.IsDir() {
				desc += " — dir"
			} else {
				desc += " — file"
			}
		}
		items = append(items, item{title: filepath.Base(p), desc: desc})
	}
	l := list.New(items, list.NewDefaultDelegate(), 0, 0)
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(true)
	l.Styles.Title = lipgloss.NewStyle().Bold(true)
	return model{list: l, help: help.New(), keys: defaultKeymap(), status: "ready"}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.list.SetSize(msg.Width, msg.Height-2)
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.keys.Quit):
			return m, tea.Quit
		case key.Matches(msg, m.keys.Enter):
			// TODO: spawn finfo --long preview panel / page
			m.status = "open: " + m.list.SelectedItem().(item).title
		case key.Matches(msg, m.keys.Refresh):
			m.status = "refreshed at " + time.Now().Format(time.Kitchen)
		}
	}
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
	title := lipgloss.NewStyle().Foreground(lipgloss.Color("63")).Bold(true).Render("finfo TUI (alpha)")
	status := lipgloss.NewStyle().Faint(true).Render(m.status)
	return title + "\n" + m.list.View() + "\n" + m.help.View(m.keys) + "  " + status + "\n"
}

func main() {
	paths := os.Args[1:]
	if len(paths) == 0 {
		paths = []string{"."}
	}
	p := tea.NewProgram(initialModel(paths), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		os.Exit(1)
	}
}

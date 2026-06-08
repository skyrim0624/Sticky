import confetti from "canvas-confetti";
import { CalendarDays, Plus, Settings } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, MouseEvent } from "react";
import { TodoRow } from "./components/TodoRow";
import { useReducedMotion } from "./hooks/use-reduced-motion";
import type { DragState, TodoItem, TodoPage } from "./types";
import {
  clearPrototypeStorage,
  createPage,
  createTodo,
  displayPageTitle,
  loadWorkspace,
  saveWorkspace,
  toMarkdown
} from "./utils/todo-storage";

const COMPLETION_SOUND_URL = "/sounds/task-complete-bell.wav";
const COMPLETION_SOUND_DELAYS = [0, 140, 280];
const CLASSIC_CONFETTI_COLORS = ["#ff3b30", "#ffcc00", "#34c759", "#0a84ff", "#af52de", "#ff9500"];
const CELL_TONES = ["#fffdf8", "#fbf7ee", "#eef8fb", "#fffdf8", "#f5fbef", "#fff4f7"];

export function App() {
  const completionAudioRef = useRef<HTMLAudioElement | null>(null);
  const [workspace, setWorkspace] = useState(() => loadWorkspace());
  const [newTodoText, setNewTodoText] = useState("");
  const [dragState, setDragState] = useState<DragState>(null);
  const reducedMotion = useReducedMotion();

  const { pages, activePageId } = workspace;
  const activePage = useMemo(
    () => pages.find((page) => page.id === activePageId) ?? pages[0],
    [activePageId, pages]
  );
  const todos = activePage?.todos ?? [];
  const listTitle = activePage?.title ?? "待办事项";
  const completed = useMemo(() => todos.filter((todo) => todo.completed), [todos]);
  const gridCellCount = Math.max(6, Math.ceil(todos.length / 3) * 3);
  const browserDate = useMemo(
    () =>
      new Intl.DateTimeFormat("en-US", {
        day: "2-digit",
        month: "short",
        year: "numeric"
      })
        .format(new Date())
        .toUpperCase(),
    []
  );
  const yearLabel = useMemo(
    () =>
      new Intl.DateTimeFormat("en-US", {
        day: "numeric",
        year: "numeric"
      })
        .format(new Date())
        .replace(",", "."),
    []
  );

  useEffect(() => {
    saveWorkspace(workspace);
  }, [workspace]);

  function updateActivePage(update: (page: TodoPage) => TodoPage) {
    setWorkspace((current) => {
      const activeIndex = current.pages.findIndex((page) => page.id === current.activePageId);
      const pageIndex = activeIndex >= 0 ? activeIndex : 0;
      const nextPages = [...current.pages];
      nextPages[pageIndex] = update(nextPages[pageIndex]);

      return {
        pages: nextPages,
        activePageId: nextPages[pageIndex].id
      };
    });
  }

  function addTodo() {
    const trimmed = newTodoText.trim();
    if (!trimmed) return;

    updateActivePage((page) => ({ ...page, todos: [createTodo(trimmed), ...page.todos] }));
    setNewTodoText("");
  }

  function toggleTodo(item: TodoItem, event: MouseEvent<HTMLElement>) {
    updateActivePage((page) =>
      updatePageTodos(page, (current) =>
        current.map((todo) => (todo.id === item.id ? { ...todo, completed: !todo.completed } : todo))
      )
    );

    if (!item.completed) {
      playCompletionSound();

      if (!reducedMotion) {
        triggerConfetti(event);
      }
    }
  }

  function triggerConfetti(event: MouseEvent<HTMLElement>) {
    const origin = {
      x: clamp(event.clientX / window.innerWidth, 0.04, 0.96),
      y: clamp(event.clientY / window.innerHeight, 0.04, 0.82)
    };

    void confetti({
      particleCount: 90,
      spread: 72,
      startVelocity: 42,
      decay: 0.9,
      scalar: 0.9,
      ticks: 170,
      origin,
      colors: CLASSIC_CONFETTI_COLORS,
      shapes: ["square", "circle"],
      disableForReducedMotion: true
    });

    window.setTimeout(() => {
      void confetti({
        particleCount: 46,
        spread: 118,
        startVelocity: 24,
        gravity: 0.82,
        scalar: 0.72,
        ticks: 210,
        origin: { x: origin.x, y: Math.max(origin.y - 0.02, 0.04) },
        colors: CLASSIC_CONFETTI_COLORS,
        shapes: ["square", "circle"],
        disableForReducedMotion: true
      });
    }, 90);
  }

  function playCompletionSound() {
    COMPLETION_SOUND_DELAYS.forEach((delay, index) => {
      window.setTimeout(() => {
        const audio = index === 0 && completionAudioRef.current ? completionAudioRef.current : new Audio(COMPLETION_SOUND_URL);
        audio.volume = 0.48;
        audio.currentTime = 0;
        void audio.play().catch(() => {
          // 浏览器可能在非用户手势或静音策略下拒绝播放，原型里静默降级。
        });
      }, delay);
    });
  }

  function deleteTodo(id: string) {
    updateActivePage((page) => updatePageTodos(page, (current) => current.filter((todo) => todo.id !== id)));
  }

  function updateText(id: string, text: string) {
    const trimmed = text.trim();
    if (!trimmed) return;
    updateActivePage((page) =>
      updatePageTodos(page, (current) => current.map((todo) => (todo.id === id ? { ...todo, text: trimmed } : todo)))
    );
  }

  function updateNote(id: string, note: string) {
    updateActivePage((page) =>
      updatePageTodos(page, (current) => current.map((todo) => (todo.id === id ? { ...todo, note } : todo)))
    );
  }

  function movePending(fromId: string, toId: string) {
    updateActivePage((page) =>
      updatePageTodos(page, (current) => {
        const pendingTodos = current.filter((todo) => !todo.completed);
        const completedTodos = current.filter((todo) => todo.completed);
        const fromIndex = pendingTodos.findIndex((todo) => todo.id === fromId);
        const toIndex = pendingTodos.findIndex((todo) => todo.id === toId);

        if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return current;

        const nextPending = [...pendingTodos];
        const [moved] = nextPending.splice(fromIndex, 1);
        nextPending.splice(toIndex, 0, moved);

        return [...nextPending, ...completedTodos];
      })
    );
  }

  async function copyMarkdown() {
    await navigator.clipboard.writeText(toMarkdown(pages));
  }

  function downloadMarkdown() {
    const blob = new Blob([toMarkdown(pages)], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "floating-todo.md";
    link.click();
    URL.revokeObjectURL(url);
  }

  function resetPrototype() {
    clearPrototypeStorage();
    setWorkspace(loadWorkspace());
    setNewTodoText("");
    setDragState(null);
  }

  function selectPage(pageId: string) {
    setWorkspace((current) => (current.pages.some((page) => page.id === pageId) ? { ...current, activePageId: pageId } : current));
    setNewTodoText("");
    setDragState(null);
  }

  function addPage(title?: string) {
    setWorkspace((current) => {
      const page = createPage(current.pages.length + 1, title);
      return {
        pages: [...current.pages, page],
        activePageId: page.id
      };
    });
    setNewTodoText("");
    setDragState(null);
  }

  return (
    <main className="app-shell">
      <section className="todo-panel" aria-label="Floating Todo Web">
        <div className="todo-content">
          <audio ref={completionAudioRef} src={COMPLETION_SOUND_URL} preload="auto" />

          <header className="panel-header">
            <span className="year-label">{yearLabel}</span>
            <div className="title-stack">
              <input
                className="list-title-input"
                value={listTitle}
                aria-label="列表标题"
                onChange={(event) => updateActivePage((page) => ({ ...page, title: event.target.value }))}
              />
              <CalendarDays className="title-calendar" size={24} strokeWidth={3} />
              <p className="task-count">
                {browserDate}
              </p>
            </div>
          </header>

          <nav className="bookmark-sidebar" aria-label="便贴书签">
            {pages.slice(0, 6).map((page, index) => {
              const pageTitle = displayPageTitle(page);
              const isActive = page.id === activePageId;
              const ratio = page.todos.length ? page.todos.filter((todo) => todo.completed).length / page.todos.length : 0;

              return (
                <button
                  key={page.id}
                  className="bookmark-tab"
                  type="button"
                  title={pageTitle}
                  aria-label={`切换到 ${pageTitle}`}
                  data-active={isActive}
                  data-completed={!isActive && ratio >= 1}
                  onClick={() => selectPage(page.id)}
                >
                  <span>{isActive ? "Today" : Array.from(pageTitle).slice(0, index === 0 ? 3 : 2).join("")}</span>
                  <strong>{index + 8}</strong>
                </button>
              );
            })}
            <button className="bookmark-add" type="button" title="新建便贴" aria-label="新建便贴" onClick={() => addPage()}>
              <span>New</span>
              <strong>+</strong>
            </button>
          </nav>

          <div className="progress-toolbar">
            <div className="task-progress">
              <span className="progress-check">✓</span>
              <span>{completed.length} / {Math.max(todos.length, 1)}</span>
            </div>
            <div className="toolbar-actions" aria-hidden="true">
              <span>?</span>
              <Settings size={21} strokeWidth={2.4} />
            </div>
          </div>

          <div className="todo-list">
            {todos.length === 0 ? (
              <div className="empty-state">
                <span>NOTHING HERE.</span>
                <p>THE MACHINE HAS NO OPINION.</p>
              </div>
            ) : (
              <>
                {Array.from({ length: gridCellCount }, (_, index) => {
                  const item = todos[index];
                  return item ? (
                    <TodoRow
                      key={item.id}
                      item={item}
                      index={index}
                      dragState={dragState}
                      onDragStateChange={setDragState}
                      onMovePending={movePending}
                      onToggle={toggleTodo}
                      onDelete={deleteTodo}
                      onUpdateText={updateText}
                      onUpdateNote={updateNote}
                    />
                  ) : (
                    <div
                      key={`empty-${index}`}
                      className="todo-placeholder"
                      style={{ "--cell-bg": CELL_TONES[index % CELL_TONES.length] } as CSSProperties}
                    />
                  );
                })}
              </>
            )}
          </div>

          <form
            className="input-bar"
            onSubmit={(event) => {
              event.preventDefault();
              addTodo();
            }}
          >
            <button className="add-icon" type="submit" title="添加待办" aria-label="添加待办">
              <Plus size={18} strokeWidth={3} />
            </button>
            <input
              value={newTodoText}
              placeholder="添加新待办..."
              aria-label="添加新待办"
              onChange={(event) => setNewTodoText(event.target.value)}
            />
          </form>
        </div>
      </section>
    </main>
  );
}

function updatePageTodos(page: TodoPage, update: (todos: TodoItem[]) => TodoItem[]) {
  return { ...page, todos: update(page.todos) };
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

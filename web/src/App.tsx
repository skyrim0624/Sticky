import { Check, Clipboard, Download, Plus, RotateCcw } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, MouseEvent } from "react";
import { Confetti } from "./components/Confetti";
import { TodoRow } from "./components/TodoRow";
import { useReducedMotion } from "./hooks/use-reduced-motion";
import type { DragState, TodoItem } from "./types";
import {
  clearPrototypeStorage,
  createTodo,
  loadTitle,
  loadTodos,
  saveTitle,
  saveTodos,
  toMarkdown
} from "./utils/todo-storage";

export function App() {
  const panelRef = useRef<HTMLElement | null>(null);
  const completionAudioRef = useRef<HTMLAudioElement | null>(null);
  const [todos, setTodos] = useState<TodoItem[]>(() => loadTodos());
  const [listTitle, setListTitle] = useState(() => loadTitle());
  const [newTodoText, setNewTodoText] = useState("");
  const [dragState, setDragState] = useState<DragState>(null);
  const [confettiBurst, setConfettiBurst] = useState(0);
  const [showsConfetti, setShowsConfetti] = useState(false);
  const [confettiOrigin, setConfettiOrigin] = useState({ x: 180, y: 120 });
  const reducedMotion = useReducedMotion();

  const pending = useMemo(() => todos.filter((todo) => !todo.completed), [todos]);
  const completed = useMemo(() => todos.filter((todo) => todo.completed), [todos]);
  const progress = todos.length ? completed.length / todos.length : 0;

  useEffect(() => {
    saveTodos(todos);
  }, [todos]);

  useEffect(() => {
    saveTitle(listTitle);
  }, [listTitle]);

  function addTodo() {
    const trimmed = newTodoText.trim();
    if (!trimmed) return;

    setTodos((current) => [createTodo(trimmed), ...current]);
    setNewTodoText("");
  }

  function toggleTodo(item: TodoItem, event: MouseEvent<HTMLElement>) {
    setTodos((current) =>
      current.map((todo) => (todo.id === item.id ? { ...todo, completed: !todo.completed } : todo))
    );

    if (!item.completed) {
      playCompletionSound();

      if (!reducedMotion) {
        triggerConfetti(event);
      }
    }
  }

  function triggerConfetti(event: MouseEvent<HTMLElement>) {
    setConfettiOrigin(getPanelPoint(event));
    setConfettiBurst((current) => current + 1);
    setShowsConfetti(true);
    window.setTimeout(() => setShowsConfetti(false), 1650);
  }

  function getPanelPoint(event: MouseEvent<HTMLElement>) {
    const rect = panelRef.current?.getBoundingClientRect();
    if (!rect) return confettiOrigin;

    return {
      x: Math.max(18, Math.min(event.clientX - rect.left, rect.width - 18)),
      y: Math.max(18, Math.min(event.clientY - rect.top, rect.height - 18))
    };
  }

  function playCompletionSound() {
    const audio = completionAudioRef.current;
    if (!audio) return;

    audio.volume = 0.58;
    audio.currentTime = 0;
    void audio.play().catch(() => {
      // 浏览器可能在非用户手势或静音策略下拒绝播放，原型里静默降级。
    });
  }

  function deleteTodo(id: string) {
    setTodos((current) => current.filter((todo) => todo.id !== id));
  }

  function updateText(id: string, text: string) {
    const trimmed = text.trim();
    if (!trimmed) return;
    setTodos((current) => current.map((todo) => (todo.id === id ? { ...todo, text: trimmed } : todo)));
  }

  function updateNote(id: string, note: string) {
    setTodos((current) => current.map((todo) => (todo.id === id ? { ...todo, note } : todo)));
  }

  function movePending(fromId: string, toId: string) {
    setTodos((current) => {
      const pendingTodos = current.filter((todo) => !todo.completed);
      const completedTodos = current.filter((todo) => todo.completed);
      const fromIndex = pendingTodos.findIndex((todo) => todo.id === fromId);
      const toIndex = pendingTodos.findIndex((todo) => todo.id === toId);

      if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return current;

      const nextPending = [...pendingTodos];
      const [moved] = nextPending.splice(fromIndex, 1);
      nextPending.splice(toIndex, 0, moved);

      return [...nextPending, ...completedTodos];
    });
  }

  async function copyMarkdown() {
    await navigator.clipboard.writeText(toMarkdown(todos));
  }

  function downloadMarkdown() {
    const blob = new Blob([toMarkdown(todos)], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "floating-todo.md";
    link.click();
    URL.revokeObjectURL(url);
  }

  function resetPrototype() {
    clearPrototypeStorage();
    setTodos(loadTodos());
    setListTitle("待办事项");
    setNewTodoText("");
  }

  return (
    <main className="app-shell">
      <section className="todo-panel" aria-label="Floating Todo Web" ref={panelRef}>
        <audio ref={completionAudioRef} src="/sounds/task-complete-success.mp3" preload="auto" />
        {showsConfetti && <Confetti burstKey={confettiBurst} origin={confettiOrigin} />}

        <header className="panel-header">
          <div className="title-stack">
            <input
              className="list-title-input"
              value={listTitle}
              aria-label="列表标题"
              onChange={(event) => setListTitle(event.target.value)}
            />
            <p className="task-count">
              <strong>{pending.length}</strong> 项待办
              {completed.length > 0 && (
                <>
                  <span> · </span>
                  <strong className="done-count">{completed.length}</strong> 已完成
                </>
              )}
            </p>
          </div>

          <div className="header-actions">
            <button className="icon-button" type="button" title="复制 Markdown" aria-label="复制 Markdown" onClick={copyMarkdown}>
              <Clipboard size={15} strokeWidth={2} />
            </button>
            <button className="icon-button" type="button" title="下载 Markdown" aria-label="下载 Markdown" onClick={downloadMarkdown}>
              <Download size={15} strokeWidth={2} />
            </button>
            <button className="icon-button" type="button" title="重置测试数据" aria-label="重置测试数据" onClick={resetPrototype}>
              <RotateCcw size={15} strokeWidth={2} />
            </button>

            <div className="progress-ring" style={{ "--progress": progress } as CSSProperties}>
              <Check size={11} strokeWidth={3} />
            </div>
          </div>
        </header>

        <div className="todo-list">
          {todos.length === 0 ? (
            <div className="empty-state">
              <span>✨</span>
              <p>享受当下的空闲时刻</p>
            </div>
          ) : (
            <>
              {pending.map((item, index) => (
                <TodoRow
                  key={item.id}
                  item={item}
                  index={index}
                  totalPending={pending.length}
                  dragState={dragState}
                  onDragStateChange={setDragState}
                  onMovePending={movePending}
                  onToggle={toggleTodo}
                  onDelete={deleteTodo}
                  onUpdateText={updateText}
                  onUpdateNote={updateNote}
                />
              ))}

              {pending.length > 0 && completed.length > 0 && (
                <div className="completed-divider">
                  <span />
                  <p>已完成</p>
                  <span />
                </div>
              )}

              {completed.map((item) => (
                <TodoRow
                  key={item.id}
                  item={item}
                  index={0}
                  totalPending={1}
                  dragState={dragState}
                  onDragStateChange={setDragState}
                  onMovePending={movePending}
                  onToggle={toggleTodo}
                  onDelete={deleteTodo}
                  onUpdateText={updateText}
                  onUpdateNote={updateNote}
                />
              ))}
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
          <span className="add-icon">
            <Plus size={13} strokeWidth={3} />
          </span>
          <input
            value={newTodoText}
            placeholder="添加新待办…"
            aria-label="添加新待办"
            onChange={(event) => setNewTodoText(event.target.value)}
          />
        </form>
      </section>
    </main>
  );
}

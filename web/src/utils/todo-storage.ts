import type { TodoItem } from "../types";

const TODOS_KEY = "floatingTodo.web.todos";
const TITLE_KEY = "floatingTodo.web.title";

const starterTodos: TodoItem[] = [
  {
    id: "seed-1",
    text: "试一次完成彩纸反馈",
    completed: false,
    createdAt: new Date().toISOString(),
    note: "Web 版先用浏览器验证交互和节奏。"
  },
  {
    id: "seed-2",
    text: "确认浏览器测试流程",
    completed: false,
    createdAt: new Date(Date.now() - 60_000).toISOString(),
    note: ""
  },
  {
    id: "seed-3",
    text: "保留 Swift 版作为当前可用版本",
    completed: true,
    createdAt: new Date(Date.now() - 120_000).toISOString(),
    note: "Electron 阶段再接桌面能力。"
  }
];

export function loadTodos(): TodoItem[] {
  try {
    const stored = window.localStorage.getItem(TODOS_KEY);
    if (!stored) return starterTodos;

    const parsed = JSON.parse(stored) as TodoItem[];
    return Array.isArray(parsed) ? parsed : starterTodos;
  } catch {
    return starterTodos;
  }
}

export function saveTodos(todos: TodoItem[]) {
  window.localStorage.setItem(TODOS_KEY, JSON.stringify(todos));
}

export function loadTitle() {
  return window.localStorage.getItem(TITLE_KEY) || "待办事项";
}

export function saveTitle(title: string) {
  window.localStorage.setItem(TITLE_KEY, title);
}

export function clearPrototypeStorage() {
  window.localStorage.removeItem(TODOS_KEY);
  window.localStorage.removeItem(TITLE_KEY);
}

export function createTodo(text: string): TodoItem {
  return {
    id: crypto.randomUUID(),
    text,
    completed: false,
    createdAt: new Date().toISOString(),
    note: ""
  };
}

export function toMarkdown(todos: TodoItem[]) {
  const lines = ["# Floating Todo", ""];

  for (const item of todos.filter((todo) => !todo.completed)) {
    lines.push(`- [ ] ${item.text}`);
    appendNote(lines, item.note);
  }

  for (const item of todos.filter((todo) => todo.completed)) {
    lines.push(`- [x] ${item.text}`);
    appendNote(lines, item.note);
  }

  lines.push("");
  return lines.join("\n");
}

function appendNote(lines: string[], note: string) {
  if (!note.trim()) return;

  for (const line of note.split("\n")) {
    lines.push(`    > ${line}`);
  }
}

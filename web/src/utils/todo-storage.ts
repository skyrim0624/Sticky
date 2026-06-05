import type { TodoItem, TodoPage, TodoWorkspace } from "../types";

const PAGES_KEY = "floatingTodo.web.pages";
const ACTIVE_PAGE_KEY = "floatingTodo.web.activePageId";
const LEGACY_TODOS_KEY = "floatingTodo.web.todos";
const LEGACY_TITLE_KEY = "floatingTodo.web.title";

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

export function loadWorkspace(): TodoWorkspace {
  const pages = loadPages();
  const storedActivePageId = window.localStorage.getItem(ACTIVE_PAGE_KEY);
  const activePageId = storedActivePageId && pages.some((page) => page.id === storedActivePageId)
    ? storedActivePageId
    : pages[0].id;

  return { pages, activePageId };
}

export function saveWorkspace(workspace: TodoWorkspace) {
  window.localStorage.setItem(PAGES_KEY, JSON.stringify(workspace.pages));
  window.localStorage.setItem(ACTIVE_PAGE_KEY, workspace.activePageId);
}

function loadPages(): TodoPage[] {
  try {
    const stored = window.localStorage.getItem(PAGES_KEY);
    if (stored) {
      const parsed = JSON.parse(stored) as TodoPage[];
      if (Array.isArray(parsed) && parsed.length > 0) return parsed;
    }

    return [createStarterPage()];
  } catch {
    return [createStarterPage()];
  }
}

function createStarterPage(): TodoPage {
  const legacyTodos = loadLegacyTodos();
  const legacyTitle = window.localStorage.getItem(LEGACY_TITLE_KEY) || "待办事项";
  return {
    id: "page-inbox",
    title: legacyTitle,
    todos: legacyTodos,
    createdAt: new Date().toISOString()
  };
}

export function clearPrototypeStorage() {
  window.localStorage.removeItem(PAGES_KEY);
  window.localStorage.removeItem(ACTIVE_PAGE_KEY);
  window.localStorage.removeItem(LEGACY_TODOS_KEY);
  window.localStorage.removeItem(LEGACY_TITLE_KEY);
}

export function createPage(index: number): TodoPage {
  return {
    id: crypto.randomUUID(),
    title: `便贴 ${index}`,
    todos: [],
    createdAt: new Date().toISOString()
  };
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

export function toMarkdown(pages: TodoPage[]) {
  const lines = ["# Floating Todo", ""];

  for (const page of pages) {
    lines.push(`## ${displayPageTitle(page)}`, "");

    for (const item of page.todos.filter((todo) => !todo.completed)) {
      lines.push(`- [ ] ${item.text}`);
      appendNote(lines, item.note);
    }

    for (const item of page.todos.filter((todo) => todo.completed)) {
      lines.push(`- [x] ${item.text}`);
      appendNote(lines, item.note);
    }

    lines.push("");
  }

  return lines.join("\n");
}

export function displayPageTitle(page: TodoPage) {
  return page.title.trim() || "未命名";
}

function loadLegacyTodos(): TodoItem[] {
  try {
    const stored = window.localStorage.getItem(LEGACY_TODOS_KEY);
    if (!stored) return starterTodos;

    const parsed = JSON.parse(stored) as TodoItem[];
    return Array.isArray(parsed) ? parsed : starterTodos;
  } catch {
    return starterTodos;
  }
}

function appendNote(lines: string[], note: string) {
  if (!note.trim()) return;

  for (const line of note.split("\n")) {
    lines.push(`    > ${line}`);
  }
}

export type TodoItem = {
  id: string;
  text: string;
  completed: boolean;
  createdAt: string;
  note: string;
};

export type TodoPage = {
  id: string;
  title: string;
  todos: TodoItem[];
  createdAt: string;
};

export type TodoWorkspace = {
  pages: TodoPage[];
  activePageId: string;
};

export type DragState = {
  itemId: string;
} | null;

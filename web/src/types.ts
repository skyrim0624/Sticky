export type TodoItem = {
  id: string;
  text: string;
  completed: boolean;
  createdAt: string;
  note: string;
};

export type DragState = {
  itemId: string;
} | null;

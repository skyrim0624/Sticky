import { Star, X } from "lucide-react";
import { useEffect, useState } from "react";
import type { CSSProperties, MouseEvent } from "react";
import type { DragState, TodoItem } from "../types";

type TodoRowProps = {
  item: TodoItem;
  index: number;
  totalPending: number;
  dragState: DragState;
  onDragStateChange: (state: DragState) => void;
  onMovePending: (fromId: string, toId: string) => void;
  onToggle: (item: TodoItem, event: MouseEvent<HTMLElement>) => void;
  onDelete: (id: string) => void;
  onUpdateText: (id: string, text: string) => void;
  onUpdateNote: (id: string, note: string) => void;
};

export function TodoRow({
  item,
  index,
  totalPending,
  dragState,
  onDragStateChange,
  onMovePending,
  onToggle,
  onDelete,
  onUpdateText,
  onUpdateNote
}: TodoRowProps) {
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleText, setTitleText] = useState(item.text);

  const priorityColor = item.completed ? "rgba(40, 40, 40, 0.18)" : priorityColorFor(index, totalPending);
  const isDragging = dragState?.itemId === item.id;
  const rowVisual = rowVisualFor(index, item.completed);

  useEffect(() => {
    setTitleText(item.text);
  }, [item.text]);

  return (
    <article
      className="todo-row"
      data-completed={item.completed}
      data-dragging={isDragging}
      draggable={!item.completed}
      onDragStart={(event) => {
        if (item.completed) return;
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("text/plain", item.id);
        onDragStateChange({ itemId: item.id });
      }}
      onDragOver={(event) => {
        if (item.completed || !dragState || dragState.itemId === item.id) return;
        event.preventDefault();
        onMovePending(dragState.itemId, item.id);
      }}
      onDragEnd={() => onDragStateChange(null)}
    >
      <div className="todo-main">
        <button
          className="check-button"
          type="button"
          aria-label={item.completed ? "标记为未完成" : "标记为已完成"}
          onClick={(event) => onToggle(item, event)}
          style={{ "--priority-color": priorityColor } as CSSProperties}
        >
          <span className="check-dot" />
        </button>

        {editingTitle && !item.completed ? (
          <input
            className="title-input"
            value={titleText}
            autoFocus
            onChange={(event) => setTitleText(event.target.value)}
            onBlur={() => {
              setEditingTitle(false);
              onUpdateText(item.id, titleText);
            }}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.currentTarget.blur();
              }
              if (event.key === "Escape") {
                setTitleText(item.text);
                setEditingTitle(false);
              }
            }}
          />
        ) : (
          <button
            className="todo-title"
            type="button"
            onClick={(event) => onToggle(item, event)}
            onDoubleClick={() => {
              if (!item.completed) setEditingTitle(true);
            }}
          >
            {item.text}
          </button>
        )}

        <span className="todo-badge">{rowVisual.badge}</span>
        <Star className="todo-star" data-starred={rowVisual.starred} size={18} strokeWidth={2.2} fill={rowVisual.starred ? "currentColor" : "none"} />

        <button
          className="icon-button delete-button"
          type="button"
          title="删除"
          aria-label="删除"
          onClick={() => onDelete(item.id)}
        >
          <X size={14} strokeWidth={2} />
        </button>
      </div>
    </article>
  );
}

function priorityColorFor(index: number, total: number) {
  if (total <= 1) return "hsl(0 74% 58%)";
  const fraction = index / Math.max(total - 1, 1);
  const hue = fraction * 145;
  return `hsl(${hue} 74% 56%)`;
}

function rowVisualFor(index: number, completed: boolean) {
  const badges = ["工作", "工作", "习惯", "生活", "学习"];
  return {
    badge: badges[index % badges.length],
    starred: completed || index === 2 || index === 3
  };
}

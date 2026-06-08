import {
  AlarmClock,
  BedDouble,
  BookOpen,
  Coffee,
  Dumbbell,
  Gamepad2,
  Laptop,
  Pill,
  TreePine,
  Utensils
} from "lucide-react";
import { useEffect, useState } from "react";
import type { CSSProperties, MouseEvent } from "react";
import type { DragState, TodoItem } from "../types";

type TodoRowProps = {
  item: TodoItem;
  index: number;
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

  const isDragging = dragState?.itemId === item.id;
  const Icon = CARD_ICONS[index % CARD_ICONS.length];

  useEffect(() => {
    setTitleText(item.text);
  }, [item.text]);

  return (
    <article
      className="todo-row"
      data-completed={item.completed}
      data-dragging={isDragging}
      style={{ "--cell-bg": cellTone(index) } as CSSProperties}
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

        {item.completed && (
          <button
            className="check-badge"
            type="button"
            aria-label="标记为未完成"
            onClick={(event) => onToggle(item, event)}
          >
            ✓
          </button>
        )}

        <button
          className="card-icon-button"
          type="button"
          aria-label={item.completed ? "标记为未完成" : "标记为已完成"}
          onClick={(event) => onToggle(item, event)}
        >
          <Icon size={34} strokeWidth={1.7} />
        </button>

        <button
          className="icon-button delete-button"
          type="button"
          title="删除"
          aria-label="删除"
          onClick={() => onDelete(item.id)}
        >
          X
        </button>
      </div>
    </article>
  );
}

const CARD_ICONS = [AlarmClock, BedDouble, Pill, Dumbbell, Utensils, Coffee, Laptop, TreePine, Gamepad2, BookOpen];
const CARD_TONES = ["#fffdf8", "#fbf7ee", "#eef8fb", "#fffdf8", "#f5fbef", "#fff4f7"];

function cellTone(index: number) {
  return CARD_TONES[index % CARD_TONES.length];
}

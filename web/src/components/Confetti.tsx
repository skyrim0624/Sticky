import { useEffect, useMemo, useState } from "react";
import type { CSSProperties } from "react";

const colors = ["#f63d57", "#ffb21f", "#31c46d", "#1c8df0", "#8d4ce8", "#ff63b2"];

type Piece = {
  id: number;
  color: string;
  width: number;
  height: number;
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  rotation: number;
  delay: number;
  duration: number;
  shape: "rect" | "circle" | "pill";
};

type ConfettiProps = {
  burstKey: number;
};

export function Confetti({ burstKey }: ConfettiProps) {
  const [active, setActive] = useState(false);
  const pieces = useMemo(() => buildPieces(burstKey), [burstKey]);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => setActive(true));
    return () => window.cancelAnimationFrame(frame);
  }, [burstKey]);

  return (
    <div className="confetti-layer" aria-hidden="true">
      {pieces.map((piece) => (
        <span
          className={`confetti-piece confetti-${piece.shape}`}
          key={piece.id}
          style={
            {
              "--color": piece.color,
              "--width": `${piece.width}px`,
              "--height": `${piece.height}px`,
              "--start-x": `${piece.startX}px`,
              "--start-y": `${piece.startY}px`,
              "--end-x": `${piece.endX}px`,
              "--end-y": `${piece.endY}px`,
              "--rotation": `${piece.rotation}deg`,
              "--delay": `${piece.delay}s`,
              "--duration": `${piece.duration}s`
            } as CSSProperties
          }
          data-active={active}
        />
      ))}
      <span className="confetti-ring" data-active={active} />
    </div>
  );
}

function buildPieces(seed: number): Piece[] {
  return Array.from({ length: 38 }, (_, index) => {
    const spread = random(index, seed, 7);
    const fall = random(index, seed, 19);
    const drift = random(index, seed, 31);
    const spin = random(index, seed, 43);
    const shapeIndex = (index + seed) % 3;

    return {
      id: index,
      color: colors[(index + seed) % colors.length],
      width: 5 + ((index + seed) % 7),
      height: index % 3 === 0 ? 5 : 9 + ((index + seed) % 6),
      startX: (spread - 0.5) * 38,
      startY: (drift - 0.5) * 16,
      endX: (spread - 0.5) * 310,
      endY: 78 + fall * 172,
      rotation: 180 + spin * 680,
      delay: (index % 9) * 0.018,
      duration: 0.78 + (index % 6) * 0.065,
      shape: shapeIndex === 0 ? "rect" : shapeIndex === 1 ? "circle" : "pill"
    };
  });
}

function random(index: number, seed: number, salt: number) {
  const raw = Math.abs((index + 1) * 1_103_515_245 + (seed + 13) * 12_345 + salt * 265_443_576);
  return (raw % 1000) / 1000;
}

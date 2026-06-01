import { useEffect, useMemo, useState } from "react";
import type { CSSProperties } from "react";

const colors = [
  "#ff2f6d",
  "#ffb21f",
  "#43e16d",
  "#1c8df0",
  "#8d4ce8",
  "#ff63b2",
  "#f6ff2e",
  "#30e7ff"
];

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
  scale: number;
  shape: "shard" | "spark" | "ribbon" | "drop";
};

type ConfettiProps = {
  burstKey: number;
  origin: {
    x: number;
    y: number;
  };
};

export function Confetti({ burstKey, origin }: ConfettiProps) {
  const [active, setActive] = useState(false);
  const pieces = useMemo(() => buildPieces(burstKey), [burstKey]);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => setActive(true));
    return () => window.cancelAnimationFrame(frame);
  }, [burstKey]);

  return (
    <div
      className="confetti-layer"
      aria-hidden="true"
      style={
        {
          "--origin-x": `${origin.x}px`,
          "--origin-y": `${origin.y}px`
        } as CSSProperties
      }
    >
      <span className="burst-flash" data-active={active} />
      <span className="burst-halo burst-halo-primary" data-active={active} />
      <span className="burst-halo burst-halo-secondary" data-active={active} />
      <span className="burst-star" data-active={active} />
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
              "--duration": `${piece.duration}s`,
              "--scale": piece.scale
            } as CSSProperties
          }
          data-active={active}
        />
      ))}
    </div>
  );
}

function buildPieces(seed: number): Piece[] {
  return Array.from({ length: 96 }, (_, index) => {
    const angle = random(index, seed, 7) * Math.PI * 2;
    const distance = 58 + random(index, seed, 19) * 260;
    const lift = random(index, seed, 31) * 90;
    const spin = random(index, seed, 43);
    const shapeIndex = (index + seed) % 4;
    const isSpark = shapeIndex === 1;

    return {
      id: index,
      color: colors[(index + seed) % colors.length],
      width: isSpark ? 4 + ((index + seed) % 4) : 7 + ((index + seed) % 11),
      height: isSpark ? 4 + ((index + seed) % 4) : 12 + ((index + seed) % 20),
      startX: (random(index, seed, 59) - 0.5) * 14,
      startY: (random(index, seed, 71) - 0.5) * 14,
      endX: Math.cos(angle) * distance,
      endY: Math.sin(angle) * distance + 56 - lift,
      rotation: 240 + spin * 980,
      delay: (index % 16) * 0.008,
      duration: 0.72 + (index % 9) * 0.06,
      scale: 0.72 + random(index, seed, 83) * 0.95,
      shape:
        shapeIndex === 0
          ? "shard"
          : shapeIndex === 1
            ? "spark"
            : shapeIndex === 2
              ? "ribbon"
              : "drop"
    };
  });
}

function random(index: number, seed: number, salt: number) {
  const raw = Math.abs((index + 1) * 1_103_515_245 + (seed + 13) * 12_345 + salt * 265_443_576);
  return (raw % 1000) / 1000;
}

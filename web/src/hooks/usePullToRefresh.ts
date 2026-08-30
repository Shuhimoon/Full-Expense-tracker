import { useEffect, useRef, useState } from "react";

/** Touch pull-to-refresh for the PWA home (or any) page. Passive listeners so we don't fight overscroll. */
export function usePullToRefresh(onRefresh: () => Promise<void>, enabled = true) {
  const [pull, setPull] = useState(0);
  const [busy, setBusy] = useState(false);
  const startY = useRef(0);
  const pulling = useRef(false);
  const dyRef = useRef(0);
  const busyRef = useRef(false);
  const cbRef = useRef(onRefresh);
  cbRef.current = onRefresh;

  useEffect(() => {
    if (!enabled) return;

    function atTop() {
      return (window.scrollY || document.documentElement.scrollTop || 0) <= 2;
    }

    function onStart(e: TouchEvent) {
      if (busyRef.current || !atTop()) {
        pulling.current = false;
        return;
      }
      startY.current = e.touches[0].clientY;
      pulling.current = true;
      dyRef.current = 0;
    }

    function onMove(e: TouchEvent) {
      if (!pulling.current || busyRef.current) return;
      const d = e.touches[0].clientY - startY.current;
      if (d > 8 && atTop()) {
        const shown = Math.min(d * 0.35, 72);
        dyRef.current = shown;
        setPull(shown);
      } else if (d <= 0) {
        dyRef.current = 0;
        setPull(0);
        pulling.current = false;
      }
    }

    async function onEnd() {
      if (!pulling.current) return;
      pulling.current = false;
      const d = dyRef.current;
      dyRef.current = 0;
      setPull(0);
      if (d < 48 || busyRef.current) return;
      busyRef.current = true;
      setBusy(true);
      try {
        await cbRef.current();
      } finally {
        busyRef.current = false;
        setBusy(false);
      }
    }

    window.addEventListener("touchstart", onStart, { passive: true });
    window.addEventListener("touchmove", onMove, { passive: true });
    window.addEventListener("touchend", onEnd, { passive: true });
    window.addEventListener("touchcancel", onEnd, { passive: true });
    return () => {
      window.removeEventListener("touchstart", onStart);
      window.removeEventListener("touchmove", onMove);
      window.removeEventListener("touchend", onEnd);
      window.removeEventListener("touchcancel", onEnd);
    };
  }, [enabled]);

  return { pull, busy };
}

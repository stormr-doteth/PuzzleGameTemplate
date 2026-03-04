-- Shared module-level touch state, written by useZoomPan and read by useDrag.
-- Using a plain table (not React state) avoids re-rendering every PuzzlePiece on each touch.
return {
	touchCount = 0,
	isDragging = false,
}

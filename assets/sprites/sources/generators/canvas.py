"""Coordinate-based pixel painting onto a char grid."""


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]

    def px(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "."

    def hline(self, x0, x1, y, ch):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.px(x, y, ch)

    def vline(self, x, y0, y1, ch):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.px(x, y, ch)

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.hline(x0, x1, y, ch)

    def line(self, x0, y0, x1, y1, ch):
        """Bresenham."""
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        x, y = x0, y0
        while True:
            self.px(x, y, ch)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy

    def rows(self, y0, spec):
        """spec: list of (x_start, string) per row starting at y0.
        Lets you place small hand-drawn patches by coordinate."""
        for dy, (x0, s) in enumerate(spec):
            for i, ch in enumerate(s):
                if ch != " ":
                    self.px(x0 + i, y0 + dy, ch)

    def outline_sprite(self, ch, targets=None):
        """Put outline ch on any transparent px orthogonally adjacent to a
        non-transparent px (auto silhouette outline). If targets given, only
        outline around those chars."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] != ".":
                    continue
                for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                    n = self.get(nx, ny)
                    if n != "." and n != ch and (targets is None or n in targets):
                        add.append((x, y))
                        break
        for x, y in add:
            self.g[y][x] = ch

    def replace(self, a, b):
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] == a:
                    self.g[y][x] = b

    def grid(self):
        return ["".join(r) for r in self.g]

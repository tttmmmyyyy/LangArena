module benchmarks.maze;

import benchmark;
import helper;
import std.stdio;
import std.algorithm;
import std.conv;
import std.array;
import std.range;
import std.typecons;
import std.container.dlist;
import std.container.array : Array;
import std.container.binaryheap : BinaryHeap;
import std.math;

enum CellKind
{
    Wall = 0,
    Space = 1,
    Start = 2,
    Finish = 3,
    Border = 4,
    Path = 5
}

class Cell
{
public:
    CellKind kind;
    Cell[] neighbors;
    int x;
    int y;

    this(int x, int y)
    {
        this.x = x;
        this.y = y;
        this.kind = CellKind.Wall;
        this.neighbors = [];
    }

    void addNeighbor(Cell cell)
    {
        neighbors ~= cell;
    }

    bool isWalkable() const
    {
        return kind == CellKind.Space || kind == CellKind.Start || kind == CellKind.Finish;
    }

    void reset()
    {
        if (kind == CellKind.Space)
        {
            kind = CellKind.Wall;
        }
    }
}

class Maze
{
private:
    int width;
    int height;
    Cell[][] cells;
    Cell start;
    Cell finish;

public:
    this(int w, int h)
    {
        width = w.max(5);
        height = h.max(5);

        cells = new Cell[][](height);
        for (int y = 0; y < height; y++)
        {
            cells[y] = new Cell[](width);
            for (int x = 0; x < width; x++)
            {
                cells[y][x] = new Cell(x, y);
            }
        }

        start = cells[1][1];
        finish = cells[height - 2][width - 2];
        start.kind = CellKind.Start;
        finish.kind = CellKind.Finish;

        updateNeighbors();
    }

    void updateNeighbors()
    {
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                auto cell = cells[y][x];

                if (x > 0 && y > 0 && x < width - 1 && y < height - 1)
                {
                    cell.addNeighbor(cells[y - 1][x]);
                    cell.addNeighbor(cells[y + 1][x]);
                    cell.addNeighbor(cells[y][x + 1]);
                    cell.addNeighbor(cells[y][x - 1]);

                    for (int t = 0; t < 4; t++)
                    {
                        int i = Helper.nextInt(4);
                        int j = Helper.nextInt(4);
                        if (i != j)
                        {
                            auto temp = cell.neighbors[i];
                            cell.neighbors[i] = cell.neighbors[j];
                            cell.neighbors[j] = temp;
                        }
                    }
                }
                else
                {
                    cell.kind = CellKind.Border;
                }
            }
        }
    }

    void reset()
    {
        foreach (row; cells)
        {
            foreach (cell; row)
            {
                cell.reset();
            }
        }
        start.kind = CellKind.Start;
        finish.kind = CellKind.Finish;
    }

    void dig(Cell startCell)
    {
        size_t stackCapacity = width * height;
        Cell[] stack = new Cell[](stackCapacity);
        size_t stackPtr = 0;

        stack[stackPtr++] = startCell;

        while (stackPtr > 0)
        {
            auto cell = stack[--stackPtr];

            int walkable = 0;
            foreach (n; cell.neighbors)
            {
                if (n.isWalkable())
                    walkable++;
            }

            if (walkable != 1)
                continue;

            cell.kind = CellKind.Space;

            foreach (n; cell.neighbors)
            {
                if (n.kind == CellKind.Wall)
                {
                    if (stackPtr >= stackCapacity)
                    {
                        stackCapacity *= 2;
                        stack.length = stackCapacity;
                    }

                    stack[stackPtr++] = n;
                }
            }
        }
    }

    void ensureOpenFinish(Cell cell)
    {
        cell.kind = CellKind.Space;

        int walkable = 0;
        foreach (n; cell.neighbors)
        {
            if (n.isWalkable())
                walkable++;
        }

        if (walkable > 1)
            return;

        foreach (n; cell.neighbors)
        {
            if (n.kind == CellKind.Wall)
            {
                ensureOpenFinish(n);
            }
        }
    }

    void generate()
    {
        foreach (n; start.neighbors)
        {
            if (n.kind == CellKind.Wall)
            {
                dig(n);
            }
        }

        foreach (n; finish.neighbors)
        {
            if (n.kind == CellKind.Wall)
            {
                ensureOpenFinish(n);
            }
        }
    }

    Cell getStart()
    {
        return start;
    }

    Cell getFinish()
    {
        return finish;
    }

    Cell middleCell()
    {
        return cells[height / 2][width / 2];
    }

    uint checksum()
    {
        uint hasher = 2166136261UL;
        uint prime = 16777619UL;

        foreach (row; cells)
        {
            foreach (cell; row)
            {
                if (cell.kind == CellKind.Space)
                {
                    uint val = cast(uint)(cell.x * cell.y);
                    hasher = (hasher ^ val) * prime;
                }
            }
        }
        return hasher;
    }

    void printToConsole()
    {
        foreach (row; cells)
        {
            foreach (cell; row)
            {
                final switch (cell.kind)
                {
                case CellKind.Space:
                    write(" ");
                    break;
                case CellKind.Wall:
                    write("\u001B[34m#\u001B[0m");
                    break;
                case CellKind.Border:
                    write("\u001B[31mO\u001B[0m");
                    break;
                case CellKind.Start:
                    write("\u001B[32m>\u001B[0m");
                    break;
                case CellKind.Finish:
                    write("\u001B[32m<\u001B[0m");
                    break;
                case CellKind.Path:
                    write("\u001B[33m.\u001B[0m");
                    break;
                }
            }
            writeln();
        }
        writeln();
    }
}

class MazeGenerator : Benchmark
{
    uint resultVal;
    int width;
    int height;
    Maze maze;

    this()
    {
        resultVal = 0;
        width = configVal("w");
        height = configVal("h");
        maze = new Maze(width, height);
    }

    override string className() const
    {
        return "Maze::Generator";
    }

    override void prepare()
    {
    }

    override void run(int iterationId)
    {
        maze.reset();
        maze.generate();
        resultVal += cast(uint) maze.middleCell().kind;
    }

    override uint checksum()
    {
        return resultVal + maze.checksum();
    }
}

class MazeBFS : Benchmark
{
private:
    uint resultVal;
    int width;
    int height;
    Maze maze;
    Cell[] path;

    Cell[] bfs(Cell start, Cell target)
    {
        if (start == target)
            return [start];

        struct PathNode
        {
            Cell cell;
            int parent;
        }

        DList!int queue;
        bool[][] visited = new bool[][](height);
        foreach (i; 0 .. height)
        {
            visited[i] = new bool[width];
        }
        PathNode[] pathNodes;

        visited[start.y][start.x] = true;
        pathNodes ~= PathNode(start, -1);
        queue.insertBack(0);

        while (!queue.empty)
        {
            int pathId = queue.front;
            queue.removeFront();
            auto cell = pathNodes[pathId].cell;

            foreach (neighbor; cell.neighbors)
            {
                if (neighbor == target)
                {
                    Cell[] result = [target];
                    int current = pathId;
                    while (current >= 0)
                    {
                        result ~= pathNodes[current].cell;
                        current = pathNodes[current].parent;
                    }
                    result.reverse;
                    return result;
                }

                if (neighbor.isWalkable() && !visited[neighbor.y][neighbor.x])
                {
                    visited[neighbor.y][neighbor.x] = true;
                    pathNodes ~= PathNode(neighbor, pathId);
                    queue.insertBack(cast(int)(pathNodes.length - 1));
                }
            }
        }
        return [];
    }

    uint midCellChecksum(Cell[] p)
    {
        if (p.length == 0)
            return 0;
        auto cell = p[p.length / 2];
        return cast(uint)(cell.x * cell.y);
    }

public:
    this()
    {
        resultVal = 0;
        width = configVal("w");
        height = configVal("h");
        maze = new Maze(width, height);
    }

    override string className() const
    {
        return "Maze::BFS";
    }

    override void prepare()
    {
        maze.generate();
    }

    override void run(int iterationId)
    {
        path = bfs(maze.getStart(), maze.getFinish());
        resultVal += cast(uint) path.length;
    }

    override uint checksum()
    {
        return resultVal + midCellChecksum(path);
    }
}

class MazeAStar : Benchmark
{
private:

    struct Entry
    {
        int priority;
        int vertex;
    }

    static bool entryLess(Entry a, Entry b)
    {
        return a.priority > b.priority;
    }

    alias AStarQueue = BinaryHeap!(Array!Entry, entryLess);

    uint resultVal;
    int width;
    int height;
    Maze maze;
    Cell[] path;

    int heuristic(Cell a, Cell b)
    {
        return abs(a.x - b.x) + abs(a.y - b.y);
    }

    int idx(int y, int x)
    {
        return y * width + x;
    }

    Cell[] astar(Cell start, Cell target)
    {
        if (start == target)
            return [start];

        int size = width * height;

        int[] cameFrom = new int[](size);
        int[] gScore = new int[](size);
        int[] bestF = new int[](size);
        foreach (i; 0 .. size)
        {
            cameFrom[i] = -1;
            gScore[i] = int.max;
            bestF[i] = int.max;
        }

        int startIdx = idx(start.y, start.x);
        int targetIdx = idx(target.y, target.x);

        AStarQueue openSet;

        gScore[startIdx] = 0;
        int fStart = heuristic(start, target);
        openSet.insert(Entry(fStart, startIdx));
        bestF[startIdx] = fStart;

        while (!openSet.empty())
        {
            auto entry = openSet.front();
            openSet.removeFront();

            int currentIdx = entry.vertex;

            if (currentIdx == targetIdx)
            {
                Cell[] result;
                int cur = currentIdx;
                while (cur != -1)
                {
                    int y = cur / width;
                    int x = cur % width;
                    result ~= maze.cells[y][x];
                    cur = cameFrom[cur];
                }
                result.reverse;
                return result;
            }

            int currentY = currentIdx / width;
            int currentX = currentIdx % width;
            auto current = maze.cells[currentY][currentX];
            int currentG = gScore[currentIdx];

            foreach (neighbor; current.neighbors)
            {
                if (!neighbor.isWalkable())
                    continue;

                int neighborIdx = idx(neighbor.y, neighbor.x);
                int tentativeG = currentG + 1;

                if (tentativeG < gScore[neighborIdx])
                {
                    cameFrom[neighborIdx] = currentIdx;
                    gScore[neighborIdx] = tentativeG;
                    int fNew = tentativeG + heuristic(neighbor, target);

                    if (fNew < bestF[neighborIdx])
                    {
                        bestF[neighborIdx] = fNew;
                        openSet.insert(Entry(fNew, neighborIdx));
                    }
                }
            }
        }

        return [];
    }

    uint midCellChecksum(Cell[] p)
    {
        if (p.length == 0)
            return 0;
        auto cell = p[p.length / 2];
        return cast(uint)(cell.x * cell.y);
    }

public:
    this()
    {
        resultVal = 0;
        width = configVal("w");
        height = configVal("h");
        maze = new Maze(width, height);
    }

    override string className() const
    {
        return "Maze::AStar";
    }

    override void prepare()
    {
        maze.generate();
    }

    override void run(int iterationId)
    {
        path = astar(maze.getStart(), maze.getFinish());
        resultVal += cast(uint) path.length;
    }

    override uint checksum()
    {
        return resultVal + midCellChecksum(path);
    }
}

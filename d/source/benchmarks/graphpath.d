module benchmarks.graphpath;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.container;
import std.range;
import std.random;
import std.typecons;
import benchmark;
import helper;

class GraphPathBenchmark : Benchmark
{
protected:
    class Graph
    {
    public:
        int vertices;
        int jumps;
        int jumpLen;
        int[][] adj;

        this(int vertices, int jumps = 3, int jumpLen = 100)
        {
            this.vertices = vertices;
            this.jumps = jumps;
            this.jumpLen = jumpLen;
            adj = new int[][](vertices);
            foreach (i; 0 .. vertices)
            {
                adj[i] = [];
            }
        }

        void addEdge(int u, int v)
        {
            adj[u] ~= v;
            adj[v] ~= u;
        }

        void generateRandom()
        {
            foreach (i; 1 .. vertices)
            {
                addEdge(i, i - 1);
            }

            foreach (v; 0 .. vertices)
            {
                int numJumps = Helper.nextInt(jumps);
                foreach (j; 0 .. numJumps)
                {
                    int offset = Helper.nextInt(jumpLen) - jumpLen / 2;
                    int u = v + offset;

                    if (u >= 0 && u < vertices && u != v)
                    {
                        addEdge(v, u);
                    }
                }
            }
        }
    }

    Graph graph;
    uint resultVal;

    this()
    {
        resultVal = 0;
    }

    abstract long test();

    override void prepare()
    {
        int vertices = to!int(configVal("vertices"));
        int jumps = to!int(configVal("jumps"));
        int jumpLen = to!int(configVal("jump_len"));
        graph = new Graph(vertices, jumps, jumpLen);
        graph.generateRandom();
    }

    override void run(int iterationId)
    {
        resultVal += cast(uint) test();
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class GraphPathBFS : GraphPathBenchmark
{
private:
    int bfsShortestPath(int start, int target)
    {
        if (start == target)
            return 0;

        bool[] visited = new bool[graph.vertices];
        struct Node
        {
            int vertex;
            int distance;
        }

        Node[] queue = new Node[graph.vertices];
        int front = 0, back = 0;

        visited[start] = true;
        queue[back++] = Node(start, 0);

        while (front < back)
        {
            Node current = queue[front++];

            foreach (neighbor; graph.adj[current.vertex])
            {
                if (neighbor == target)
                    return current.distance + 1;

                if (!visited[neighbor])
                {
                    visited[neighbor] = true;
                    queue[back++] = Node(neighbor, current.distance + 1);
                }
            }
        }

        return -1;
    }

protected:
    override string className() const
    {
        return "Graph::BFS";
    }

public:
    override long test()
    {
        return bfsShortestPath(0, graph.vertices - 1);
    }
}

class GraphPathDFS : GraphPathBenchmark
{
private:
    int dfsFindPath(int start, int target)
    {
        if (start == target)
            return 0;

        auto visited = new bool[graph.vertices];
        auto stack = new Tuple!(int, int)[graph.vertices];
        int top = 0;
        int bestPath = int.max;

        stack[top++] = tuple(start, 0);

        while (top > 0)
        {
            auto current = stack[--top];
            int v = current[0];
            int dist = current[1];

            if (visited[v] || dist >= bestPath)
                continue;
            visited[v] = true;

            foreach (neighbor; graph.adj[v])
            {
                if (neighbor == target)
                {
                    if (dist + 1 < bestPath)
                        bestPath = dist + 1;
                }
                else if (!visited[neighbor])
                {
                    stack[top++] = tuple(neighbor, dist + 1);
                }
            }
        }

        return bestPath == int.max ? -1 : bestPath;
    }

protected:
    override string className() const
    {
        return "Graph::DFS";
    }

public:
    override long test()
    {
        return dfsFindPath(0, graph.vertices - 1);
    }
}

class GraphPathAStar : GraphPathBenchmark
{
private:
    struct Node
    {
        int priority;
        int vertex;

        bool opCmp(const Node other) const
        {
            if (priority != other.priority)
                return priority > other.priority;
            return vertex > other.vertex;
        }
    }

    alias AStarQueue = BinaryHeap!(Array!Node, "a.opCmp(b) > 0");

    int heuristic(int v, int target)
    {
        return target - v;
    }

    int aStarShortestPath(int start, int target)
    {
        if (start == target)
            return 0;

        int n = graph.vertices;

        int[] gScore = new int[n];
        int[] bestF = new int[n];

        foreach (i; 0 .. n)
        {
            gScore[i] = int.max;
            bestF[i] = int.max;
        }

        gScore[start] = 0;
        int fStart = heuristic(start, target);
        bestF[start] = fStart;

        auto openSet = AStarQueue();
        openSet.insert(Node(fStart, start));

        while (!openSet.empty())
        {
            auto current = openSet.front();
            openSet.removeFront();

            int currentVertex = current.vertex;

            if (currentVertex == target)
            {
                return gScore[currentVertex];
            }

            foreach (neighbor; graph.adj[currentVertex])
            {
                int tentativeG = gScore[currentVertex] + 1;

                if (tentativeG < gScore[neighbor])
                {
                    gScore[neighbor] = tentativeG;
                    int fNew = tentativeG + heuristic(neighbor, target);

                    if (fNew < bestF[neighbor])
                    {
                        bestF[neighbor] = fNew;
                        openSet.insert(Node(fNew, neighbor));
                    }
                }
            }
        }

        return -1;
    }

protected:
    override string className() const
    {
        return "Graph::AStar";
    }

public:
    override long test()
    {
        return aStarShortestPath(0, graph.vertices - 1);
    }
}

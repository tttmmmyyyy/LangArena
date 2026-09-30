package benchmarks;

import java.util.*;

public abstract class GraphPathBenchmark extends Benchmark {

    static class Step {
        final int vertex;
        final int dist;

        Step(int vertex, int dist) {
            this.vertex = vertex;
            this.dist = dist;
        }
    }

    static class Graph {
        final int vertices;
        final int jumps;
        final int jumpLen;
        final List<List<Integer>> adj;

        Graph(int vertices, int jumps, int jumpLen) {
            this.vertices = vertices;
            this.jumps = jumps;
            this.jumpLen = jumpLen;
            this.adj = new ArrayList<>(vertices);

            for (int i = 0; i < vertices; i++) {
                adj.add(new ArrayList<>());
            }
        }

        void addEdge(int u, int v) {
            adj.get(u).add(v);
            adj.get(v).add(u);
        }

        void generateRandom() {

            for (int i = 1; i < vertices; i++) {
                addEdge(i, i - 1);
            }

            for (int v = 0; v < vertices; v++) {
                int numJumps = Helper.nextInt(jumps);
                for (int j = 0; j < numJumps; j++) {
                    int offset = Helper.nextInt(jumpLen) - jumpLen / 2;
                    int u = v + offset;

                    if (u >= 0 && u < vertices && u != v) {
                        addEdge(v, u);
                    }
                }
            }
        }
    }

    protected Graph graph;
    private long resultVal;

    public GraphPathBenchmark() {
        resultVal = 0L;
    }

    @Override
    public void prepare() {
        int vertices = (int) configVal("vertices");
        int jumps = (int) configVal("jumps");
        int jumpLen = (int) configVal("jump_len");

        graph = new Graph(vertices, jumps, jumpLen);
        graph.generateRandom();
    }

    abstract long test();

    @Override
    public void run(int iterationId) {
        resultVal += test();
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class GraphPathBFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "Graph::BFS";
    }

    @Override
    long test() {
        return bfsShortestPath(0, graph.vertices - 1);
    }

    private int bfsShortestPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Queue<Step> queue = new ArrayDeque<>();

        visited[start] = true;
        queue.add(new Step(start, 0));

        while (!queue.isEmpty()) {
            Step current = queue.poll();
            int v = current.vertex;
            int dist = current.dist;

            for (int neighbor : graph.adj.get(v)) {
                if (neighbor == target) return dist + 1;

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue.add(new Step(neighbor, dist + 1));
                }
            }
        }

        return -1;
    }
}

class GraphPathDFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "Graph::DFS";
    }

    @Override
    long test() {
        return dfsFindPath(0, graph.vertices - 1);
    }

    private int dfsFindPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Deque<Step> stack = new ArrayDeque<>();
        int bestPath = Integer.MAX_VALUE;

        stack.push(new Step(start, 0));

        while (!stack.isEmpty()) {
            Step current = stack.pop();
            int v = current.vertex;
            int dist = current.dist;

            if (visited[v] || dist >= bestPath) continue;
            visited[v] = true;

            for (int neighbor : graph.adj.get(v)) {
                if (neighbor == target) {
                    if (dist + 1 < bestPath) {
                        bestPath = dist + 1;
                    }
                } else if (!visited[neighbor]) {
                    stack.push(new Step(neighbor, dist + 1));
                }
            }
        }

        return bestPath == Integer.MAX_VALUE ? -1 : bestPath;
    }
}

class GraphPriorityQueueItem implements Comparable<GraphPriorityQueueItem> {
    final int priority;
    final int vertex;

    GraphPriorityQueueItem(int priority, int vertex) {
        this.priority = priority;
        this.vertex = vertex;
    }

    @Override
    public int compareTo(GraphPriorityQueueItem other) {
        if (this.priority != other.priority)
            return Integer.compare(this.priority, other.priority);
        return Integer.compare(this.vertex, other.vertex);
    }
}

class GraphPathAStar extends GraphPathBenchmark {

    @Override
    public String name() {
        return "Graph::AStar";
    }

    @Override
    long test() {
        return aStarShortestPath(0, graph.vertices - 1);
    }

    private int heuristic(int v, int target) {
        return target - v;
    }

    private int aStarShortestPath(int start, int target) {
        if (start == target) return 0;

        int n = graph.vertices;

        int[] gScore = new int[n];
        int[] bestF = new int[n];

        Arrays.fill(gScore, Integer.MAX_VALUE);
        Arrays.fill(bestF, Integer.MAX_VALUE);

        gScore[start] = 0;
        int fStart = heuristic(start, target);
        bestF[start] = fStart;

        PriorityQueue<GraphPriorityQueueItem> openSet = new PriorityQueue<>();
        openSet.add(new GraphPriorityQueueItem(fStart, start));

        while (!openSet.isEmpty()) {
            GraphPriorityQueueItem current = openSet.poll();
            int currentVertex = current.vertex;

            if (currentVertex == target) {
                return gScore[currentVertex];
            }

            for (int neighbor : graph.adj.get(currentVertex)) {
                int tentativeG = gScore[currentVertex] + 1;

                if (tentativeG < gScore[neighbor]) {
                    gScore[neighbor] = tentativeG;
                    int fNew = tentativeG + heuristic(neighbor, target);

                    if (fNew < bestF[neighbor]) {
                        bestF[neighbor] = fNew;
                        openSet.add(new GraphPriorityQueueItem(fNew, neighbor));
                    }
                }
            }
        }

        return -1;
    }
}
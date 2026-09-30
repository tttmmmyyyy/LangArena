package benchmarks

import Benchmark
import java.util.ArrayDeque
import java.util.PriorityQueue

abstract class GraphPathBenchmark : Benchmark() {
    protected class Graph(
        val vertices: Int,
        val jumps: Int = 3,
        val jumpLen: Int = 100,
    ) {
        val adj = Array(vertices) { mutableListOf<Int>() }

        fun addEdge(
            u: Int,
            v: Int,
        ) {
            adj[u].add(v)
            adj[v].add(u)
        }

        fun generateRandom() {
            for (i in 1 until vertices) {
                addEdge(i, i - 1)
            }

            for (v in 0 until vertices) {
                val numJumps = Helper.nextInt(jumps)
                repeat(numJumps) {
                    val offset = Helper.nextInt(jumpLen) - jumpLen / 2
                    val u = v + offset

                    if (u >= 0 && u < vertices && u != v) {
                        addEdge(v, u)
                    }
                }
            }
        }
    }

    protected data class Step(
        val vertex: Int,
        val dist: Int,
    )

    protected lateinit var graph: Graph
    private var resultVal: UInt = 0u

    override fun prepare() {
        val vertices = configVal("vertices").toInt()
        val jumps = configVal("jumps").toInt()
        val jumpLen = configVal("jump_len").toInt()

        graph = Graph(vertices, jumps, jumpLen)
        graph.generateRandom()
    }

    abstract fun test(): Int

    override fun run(iterationId: Int) {
        resultVal += test().toUInt()
    }

    override fun checksum(): UInt = resultVal
}

class GraphPathBFS : GraphPathBenchmark() {
    private fun bfsShortestPath(
        start: Int,
        target: Int,
    ): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val queue = ArrayDeque<Step>()

        visited[start] = true
        queue.add(Step(start, 0))

        while (queue.isNotEmpty()) {
            val (v, dist) = queue.removeFirst()

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) return dist + 1

                if (!visited[neighbor]) {
                    visited[neighbor] = true
                    queue.add(Step(neighbor, dist + 1))
                }
            }
        }

        return -1
    }

    override fun test(): Int = bfsShortestPath(0, graph.vertices - 1)

    override fun name(): String = "Graph::BFS"
}

class GraphPathDFS : GraphPathBenchmark() {
    private fun dfsFindPath(
        start: Int,
        target: Int,
    ): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val stack = ArrayDeque<Step>()
        var bestPath = Int.MAX_VALUE

        stack.add(Step(start, 0))

        while (stack.isNotEmpty()) {
            val (v, dist) = stack.removeLast()

            if (visited[v] || dist >= bestPath) continue
            visited[v] = true

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) {
                    if (dist + 1 < bestPath) bestPath = dist + 1
                } else if (!visited[neighbor]) {
                    stack.add(Step(neighbor, dist + 1))
                }
            }
        }

        return if (bestPath == Int.MAX_VALUE) -1 else bestPath
    }

    override fun test(): Int = dfsFindPath(0, graph.vertices - 1)

    override fun name(): String = "Graph::DFS"
}

class GraphPriorityQueueItem(
    val priority: Int,
    val vertex: Int,
) : Comparable<GraphPriorityQueueItem> {
    override fun compareTo(other: GraphPriorityQueueItem): Int =
        if (priority != other.priority) {
            priority.compareTo(other.priority)
        } else {
            vertex.compareTo(other.vertex)
        }
}

class GraphPathAStar : GraphPathBenchmark() {
    private fun heuristic(
        v: Int,
        target: Int,
    ): Int = target - v

    private fun aStarShortestPath(
        start: Int,
        target: Int,
    ): Int {
        if (start == target) return 0

        val n = graph.vertices

        val gScore = IntArray(n) { Int.MAX_VALUE }
        val bestF = IntArray(n) { Int.MAX_VALUE }

        gScore[start] = 0
        val fStart = heuristic(start, target)
        bestF[start] = fStart

        val openSet = PriorityQueue<GraphPriorityQueueItem>()
        openSet.add(GraphPriorityQueueItem(fStart, start))

        while (openSet.isNotEmpty()) {
            val current = openSet.poll()
            val currentVertex = current.vertex

            if (currentVertex == target) {
                return gScore[currentVertex]
            }

            for (neighbor in graph.adj[currentVertex]) {
                val tentativeG = gScore[currentVertex] + 1

                if (tentativeG < gScore[neighbor]) {
                    gScore[neighbor] = tentativeG
                    val fNew = tentativeG + heuristic(neighbor, target)

                    if (fNew < bestF[neighbor]) {
                        bestF[neighbor] = fNew
                        openSet.add(GraphPriorityQueueItem(fNew, neighbor))
                    }
                }
            }
        }

        return -1
    }

    override fun test(): Int = aStarShortestPath(0, graph.vertices - 1)

    override fun name(): String = "Graph::AStar"
}

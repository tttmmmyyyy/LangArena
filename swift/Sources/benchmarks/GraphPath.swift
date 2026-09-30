import Collections
import Foundation

class GraphPathBenchmark: BenchmarkProtocol {
  final class Graph {
    let vertices: Int
    let jumps: Int
    let jumpLen: Int
    var adj: [[Int]]

    init(vertices: Int, jumps: Int = 3, jumpLen: Int = 100) {
      self.vertices = vertices
      self.jumps = jumps
      self.jumpLen = jumpLen
      self.adj = Array(repeating: [Int](), count: vertices)
    }

    func addEdge(_ u: Int, _ v: Int) {
      adj[u].append(v)
      adj[v].append(u)
    }

    func generateRandom() {

      for i in 1..<vertices {
        addEdge(i, i - 1)
      }

      for v in 0..<vertices {
        let numJumps = Helper.nextInt(max: jumps)
        for _ in 0..<numJumps {
          let offset = Helper.nextInt(max: jumpLen) - jumpLen / 2
          let u = v + offset

          if u >= 0 && u < vertices && u != v {
            addEdge(v, u)
          }
        }
      }
    }
  }

  var graph: Graph!
  private var resultVal: UInt32 = 0

  init() {}

  func prepare() {
    let vertices = Int(configValue("vertices") ?? 0)
    let jumps = Int(configValue("jumps") ?? 0)
    let jumpLen = Int(configValue("jump_len") ?? 0)

    graph = Graph(vertices: vertices, jumps: jumps, jumpLen: jumpLen)
    graph.generateRandom()
  }

  func test() -> Int64 {
    return 0
  }

  func run(iterationId: Int) {
    resultVal &+= UInt32(test())
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return ""
  }
}

final class GraphPathBFS: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func bfsShortestPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    var visited = [Bool](repeating: false, count: graph.vertices)
    var queue: [(Int, Int)] = []
    queue.reserveCapacity(graph.vertices)
    visited[start] = true
    queue.append((start, 0))
    var front = 0

    while front < queue.count {
      let (v, dist) = queue[front]
      front += 1

      for neighbor in graph.adj[v] {
        if neighbor == target { return dist + 1 }
        if !visited[neighbor] {
          visited[neighbor] = true
          queue.append((neighbor, dist + 1))
        }
      }
    }
    return -1
  }

  override func test() -> Int64 {
    return Int64(bfsShortestPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::BFS"
  }
}

final class GraphPathDFS: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func dfsFindPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    var visited = [Bool](repeating: false, count: graph.vertices)
    var stack: [(Int, Int)] = [(start, 0)]
    var bestPath = Int.max

    while !stack.isEmpty {
      let (v, dist) = stack.removeLast()

      if visited[v] || dist >= bestPath {
        continue
      }

      visited[v] = true

      for neighbor in graph.adj[v] {
        if neighbor == target {
          if dist + 1 < bestPath {
            bestPath = dist + 1
          }
        } else if !visited[neighbor] {
          stack.append((neighbor, dist + 1))
        }
      }
    }

    return bestPath == Int.max ? -1 : bestPath
  }

  override func test() -> Int64 {
    return Int64(dfsFindPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::DFS"
  }
}

struct GraphAStarEntry: Comparable {
  let priority: Int
  let vertex: Int

  static func < (lhs: GraphAStarEntry, rhs: GraphAStarEntry) -> Bool {
    if lhs.priority != rhs.priority {
      return lhs.priority < rhs.priority
    }
    return lhs.vertex < rhs.vertex
  }

  static func == (lhs: GraphAStarEntry, rhs: GraphAStarEntry) -> Bool {
    lhs.priority == rhs.priority && lhs.vertex == rhs.vertex
  }
}

final class GraphPathAStar: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func heuristic(_ v: Int, _ target: Int) -> Int {
    return target - v
  }

  private func aStarShortestPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    let n = graph.vertices
    var gScore = [Int](repeating: Int.max, count: n)
    var bestF = [Int](repeating: Int.max, count: n)

    gScore[start] = 0
    let fStart = heuristic(start, target)
    bestF[start] = fStart

    var openSet = Heap<GraphAStarEntry>(minimumCapacity: n)
    openSet.insert(GraphAStarEntry(priority: fStart, vertex: start))

    while !openSet.isEmpty {
      guard let entry = openSet.popMin() else { break }
      let current = entry.vertex

      if current == target {
        return gScore[current]
      }

      for neighbor in graph.adj[current] {
        let tentativeG = gScore[current] + 1

        if tentativeG < gScore[neighbor] {
          gScore[neighbor] = tentativeG
          let fNew = tentativeG + heuristic(neighbor, target)

          if fNew < bestF[neighbor] {
            bestF[neighbor] = fNew
            openSet.insert(GraphAStarEntry(priority: fNew, vertex: neighbor))
          }
        }
      }
    }

    return -1
  }

  override func test() -> Int64 {
    return Int64(aStarShortestPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::AStar"
  }
}

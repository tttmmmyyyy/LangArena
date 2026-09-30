package main

import "container/heap"

type Pair struct {
	vertex   int
	distance int
}

type Graph struct {
	vertices int
	jumps    int
	jumpLen  int
	adj      [][]int
}

func NewGraph(vertices, jumps, jumpLen int) *Graph {
	adj := make([][]int, vertices)
	for i := range adj {
		adj[i] = make([]int, 0)
	}
	return &Graph{
		vertices: vertices,
		jumps:    jumps,
		jumpLen:  jumpLen,
		adj:      adj,
	}
}

func (g *Graph) AddEdge(u, v int) {
	g.adj[u] = append(g.adj[u], v)
	g.adj[v] = append(g.adj[v], u)
}

func (g *Graph) GenerateRandom() {
	for i := 1; i < g.vertices; i++ {
		g.AddEdge(i, i-1)
	}

	for v := 0; v < g.vertices; v++ {
		numJumps := NextInt(g.jumps)
		for j := 0; j < numJumps; j++ {
			offset := NextInt(g.jumpLen) - g.jumpLen/2
			u := v + offset

			if u >= 0 && u < g.vertices && u != v {
				g.AddEdge(v, u)
			}
		}
	}
}

type GraphPathBFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathBFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathBFS) bfsShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	queue := []Pair{{start, 0}}
	visited[start] = 1

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		v := current.vertex
		dist := current.distance

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				return dist + 1
			}

			if visited[neighbor] == 0 {
				visited[neighbor] = 1
				queue = append(queue, Pair{neighbor, dist + 1})
			}
		}
	}

	return -1
}

func (g *GraphPathBFS) Run(iteration_id int) {
	length := g.bfsShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathBFS) Checksum() uint32 {
	return g.result
}

type GraphPathDFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathDFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathDFS) dfsFindPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	stack := []Pair{{start, 0}}
	bestPath := int(^uint(0) >> 1)

	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		v := current.vertex
		dist := current.distance

		if visited[v] == 1 || dist >= bestPath {
			continue
		}
		visited[v] = 1

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				if dist+1 < bestPath {
					bestPath = dist + 1
				}
			} else if visited[neighbor] == 0 {
				stack = append(stack, Pair{neighbor, dist + 1})
			}
		}
	}

	if bestPath == int(^uint(0)>>1) {
		return -1
	}
	return bestPath
}

func (g *GraphPathDFS) Run(iteration_id int) {
	length := g.dfsFindPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathDFS) Checksum() uint32 {
	return g.result
}

type GraphAStarNode struct {
	vertex   int
	priority int
	index    int
}

type GraphAStarPriorityQueue []*GraphAStarNode

func (pq GraphAStarPriorityQueue) Len() int { return len(pq) }

func (pq GraphAStarPriorityQueue) Less(i, j int) bool {
	return pq[i].priority < pq[j].priority
}

func (pq GraphAStarPriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *GraphAStarPriorityQueue) Push(x interface{}) {
	n := len(*pq)
	item := x.(*GraphAStarNode)
	item.index = n
	*pq = append(*pq, item)
}

func (pq *GraphAStarPriorityQueue) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	old[n-1] = nil
	item.index = -1
	*pq = old[0 : n-1]
	return item
}

type GraphPathAStar struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathAStar) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathAStar) heuristic(v, target int) int {
	return target - v
}

func (g *GraphPathAStar) aStarShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	const INF = int(^uint(0) >> 1)
	n := g.graph.vertices

	gScore := make([]int, n)
	bestF := make([]int, n)

	for i := range gScore {
		gScore[i] = INF
		bestF[i] = INF
	}

	gScore[start] = 0
	fStart := g.heuristic(start, target)
	bestF[start] = fStart

	openSet := &GraphAStarPriorityQueue{}
	heap.Init(openSet)
	heap.Push(openSet, &GraphAStarNode{vertex: start, priority: fStart})

	for openSet.Len() > 0 {
		currentNode := heap.Pop(openSet).(*GraphAStarNode)
		current := currentNode.vertex

		if current == target {
			return gScore[current]
		}

		for _, neighbor := range g.graph.adj[current] {
			tentativeG := gScore[current] + 1

			if tentativeG < gScore[neighbor] {
				gScore[neighbor] = tentativeG
				fNew := tentativeG + g.heuristic(neighbor, target)

				if fNew < bestF[neighbor] {
					bestF[neighbor] = fNew
					heap.Push(openSet, &GraphAStarNode{vertex: neighbor, priority: fNew})
				}
			}
		}
	}

	return -1
}

func (g *GraphPathAStar) Run(iteration_id int) {
	length := g.aStarShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathAStar) Checksum() uint32 {
	return g.result
}

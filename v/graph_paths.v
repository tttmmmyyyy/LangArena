module graph_paths

import benchmark
import helper
import datatypes

struct Graph {
pub:
	vertices int
	jumps    int
	jump_len int
pub mut:
	adj [][]int
}

pub fn graph_new(vertices int, jumps int, jump_len int) &Graph {
	mut adj := [][]int{len: vertices}
	return &Graph{
		vertices: vertices
		jumps:    jumps
		jump_len: jump_len
		adj:      adj
	}
}

pub fn (mut graph Graph) add_edge(u int, v int) {
	graph.adj[u] << v
	graph.adj[v] << u
}

pub fn (mut graph Graph) generate_random() {
	for i in 1 .. graph.vertices {
		graph.add_edge(i, i - 1)
	}

	for v in 0 .. graph.vertices {
		num_jumps := helper.next_int(graph.jumps)
		for _ in 0 .. num_jumps {
			offset := helper.next_int(graph.jump_len) - graph.jump_len / 2
			u := v + offset

			if u >= 0 && u < graph.vertices && u != v {
				graph.add_edge(v, u)
			}
		}
	}
}

struct Pair {
	a int
	b int
}

struct GraphPathBenchmark {
	benchmark.BaseBenchmark
pub mut:
	graph &Graph = unsafe { nil }
mut:
	result_val u32
}

fn new_graph_path_benchmark(class_name string) GraphPathBenchmark {
	return GraphPathBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark(class_name)
		result_val:    0
	}
}

pub struct GraphPathBFS {
	GraphPathBenchmark
}

pub fn new_graphpathbfs() &benchmark.IBenchmark {
	mut bench := &GraphPathBFS{
		GraphPathBenchmark: new_graph_path_benchmark('Graph::BFS')
	}
	return bench
}

pub fn (b GraphPathBFS) name() string {
	return 'Graph::BFS'
}

fn bfs_shortest_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	mut visited := []u8{len: graph.vertices, init: 0}
	mut queue := []Pair{}
	mut head := 0

	visited[start] = 1
	queue << Pair{start, 0}

	for head < queue.len {
		current := queue[head]
		head++
		v := current.a
		dist := current.b

		for neighbor in graph.adj[v] {
			if neighbor == target {
				return dist + 1
			}

			if visited[neighbor] == 0 {
				visited[neighbor] = 1
				queue << Pair{neighbor, dist + 1}
			}
		}
	}

	return -1
}

pub fn (mut b GraphPathBFS) prepare() {
	vertices := int(helper.config_i64('Graph::BFS', 'vertices'))
	jumps := int(helper.config_i64('Graph::BFS', 'jumps'))
	jump_len := int(helper.config_i64('Graph::BFS', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathBFS) run(iteration_id int) {
	length := bfs_shortest_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathBFS) checksum() u32 {
	return b.result_val
}

pub struct GraphPathDFS {
	GraphPathBenchmark
}

pub fn new_graphpathdfs() &benchmark.IBenchmark {
	mut bench := &GraphPathDFS{
		GraphPathBenchmark: new_graph_path_benchmark('Graph::DFS')
	}
	return bench
}

pub fn (b GraphPathDFS) name() string {
	return 'Graph::DFS'
}

fn dfs_find_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	mut visited := []u8{len: graph.vertices, init: 0}
	mut stack := []Pair{}
	mut best_path := int(0x7fffffff)

	stack << Pair{start, 0}

	for stack.len > 0 {
		current := stack[stack.len - 1]
		stack.delete_last()
		v := current.a
		dist := current.b

		if visited[v] == 1 || dist >= best_path {
			continue
		}
		visited[v] = 1

		for neighbor in graph.adj[v] {
			if neighbor == target {
				if dist + 1 < best_path {
					best_path = dist + 1
				}
			} else if visited[neighbor] == 0 {
				stack << Pair{neighbor, dist + 1}
			}
		}
	}

	return if best_path == int(0x7fffffff) { -1 } else { best_path }
}

pub fn (mut b GraphPathDFS) prepare() {
	vertices := int(helper.config_i64('Graph::DFS', 'vertices'))
	jumps := int(helper.config_i64('Graph::DFS', 'jumps'))
	jump_len := int(helper.config_i64('Graph::DFS', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathDFS) run(iteration_id int) {
	length := dfs_find_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathDFS) checksum() u32 {
	return b.result_val
}

struct AStarItem {
	priority int
	vertex   int
}

fn (a AStarItem) < (b AStarItem) bool {
	if a.priority != b.priority {
		return a.priority < b.priority
	}
	return a.vertex < b.vertex
}

pub struct GraphPathAStar {
	GraphPathBenchmark
}

pub fn new_graphpathastar() &benchmark.IBenchmark {
	mut bench := &GraphPathAStar{
		GraphPathBenchmark: new_graph_path_benchmark('Graph::AStar')
	}
	return bench
}

pub fn (b GraphPathAStar) name() string {
	return 'Graph::AStar'
}

fn heuristic(v int, target int) int {
	return target - v
}

fn a_star_shortest_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	n := graph.vertices
	inf := int(0x7fffffff)

	mut g_score := []int{len: n, init: inf}
	mut best_f := []int{len: n, init: inf}

	g_score[start] = 0
	f_start := heuristic(start, target)
	best_f[start] = f_start

	mut open_set := datatypes.MinHeap[AStarItem]{}
	open_set.insert(AStarItem{f_start, start})

	for open_set.len() > 0 {
		entry := open_set.pop() or { break }
		current := entry.vertex

		if current == target {
			return g_score[current]
		}

		for neighbor in graph.adj[current] {
			tentative_g := g_score[current] + 1

			if tentative_g < g_score[neighbor] {
				g_score[neighbor] = tentative_g
				f_new := tentative_g + heuristic(neighbor, target)

				if f_new < best_f[neighbor] {
					best_f[neighbor] = f_new
					open_set.insert(AStarItem{f_new, neighbor})
				}
			}
		}
	}

	return -1
}

pub fn (mut b GraphPathAStar) prepare() {
	vertices := int(helper.config_i64('Graph::AStar', 'vertices'))
	jumps := int(helper.config_i64('Graph::AStar', 'jumps'))
	jump_len := int(helper.config_i64('Graph::AStar', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathAStar) run(iteration_id int) {
	length := a_star_shortest_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathAStar) checksum() u32 {
	return b.result_val
}

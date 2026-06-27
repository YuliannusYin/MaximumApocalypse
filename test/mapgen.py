import random

def generate_connected_shape(rows, cols, num_ones):
    # 边缘情况
    if num_ones <= 0:
        return [[0 for _ in range(cols)] for _ in range(rows)]
    if num_ones > rows * cols:
        print(f"警告：{num_ones} 超过总格数 {rows*cols}，将填满整个矩阵")
        num_ones = rows * cols

    # 初始化矩阵
    matrix = [[0 for _ in range(cols)] for _ in range(rows)]
    
    # 随机选择起始点
    start_x = random.randint(0, rows - 1)
    start_y = random.randint(0, cols - 1)
    matrix[start_x][start_y] = 1
    
    # 使用一个队列/列表来存储边界（已生成块周围的待选位置）
    # 用集合去重，用列表随机选
    frontier_set = set()
    frontier_list = []
    
    # 定义方向
    directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    
    # 初始化边界
    for dx, dy in directions:
        nx, ny = start_x + dx, start_y + dy
        if 0 <= nx < rows and 0 <= ny < cols:
            if (nx, ny) not in frontier_set:
                frontier_set.add((nx, ny))
                frontier_list.append((nx, ny))
                
    # 已放置计数
    count = 1
    
    while count < num_ones and frontier_list:
        # 随机选择一个边界点
        idx = random.randint(0, len(frontier_list) - 1)
        # 交换以高效移除（O(1)）
        frontier_list[idx], frontier_list[-1] = frontier_list[-1], frontier_list[idx]
        x, y = frontier_list.pop()
        frontier_set.remove((x, y))
        
        # 放置 1
        matrix[x][y] = 1
        count += 1
        
        # 添加新的邻居到边界
        for dx, dy in directions:
            nx, ny = x + dx, y + dy
            if 0 <= nx < rows and 0 <= ny < cols:
                if matrix[nx][ny] == 0 and (nx, ny) not in frontier_set:
                    frontier_set.add((nx, ny))
                    frontier_list.append((nx, ny))
                    
    return matrix

# 示例用法
def print_matrix(matrix):
    for row in matrix:
        print(' '.join(map(str, row)))

if __name__ == "__main__":
    # 生成一个 10x10 的矩阵，包含 15 个连通的 1
    mat = generate_connected_shape(10, 10, 30)
    print_matrix(mat)
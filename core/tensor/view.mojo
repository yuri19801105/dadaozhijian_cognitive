# === core/tensor/view.mojo ===
# 张量视图/变形原语: 转置、切片、广播加。
# 因 Tensor 结构体含 List 字段不可按值移动, 这里以自由函数 + List[Float64] 数据/List[Int] 形状
# 作为载体, 返回结果数据 List[Float64]; 调用方按需用其构建新 Tensor。
# 约定: 这些函数只处理 2D(row-major, flat = r*cols + c); 多维广播由 broadcast_add 通用实现。

# 取扁平下标 idx 在形状 shape 下第 d 维的坐标 (不依赖 List.insert, 纯除法)
def _coord_at(idx: Int, shape: List[Int], d: Int) -> Int:
    var rem = idx
    for k in range(d + 1, len(shape)):
        rem = rem // shape[k]
    return rem % shape[d]


# 2D 转置: shape [rows, cols] -> 输出 [cols, rows], flat_out = c*rows + r
def transpose_2d(data: List[Float64], shape: List[Int]) -> List[Float64]:
    var rows = shape[0]
    var cols = shape[1]
    var out = List[Float64]()
    for c in range(cols):
        for r in range(rows):
            out.append(data[r * cols + c])
    return out^


# 行切片 [r0, r1): shape [rows, cols] -> [r1-r0, cols]
def slice_rows(data: List[Float64], shape: List[Int], r0: Int, r1: Int) raises -> List[Float64]:
    var rows = shape[0]
    var cols = shape[1]
    if r0 < 0 or r1 > rows or r0 >= r1:
        raise Error("slice_rows: out of bounds")
    var out = List[Float64]()
    for r in range(r0, r1):
        for c in range(cols):
            out.append(data[r * cols + c])
    return out^


# 列切片 [c0, c1): shape [rows, cols] -> [rows, c1-c0]
def slice_cols(data: List[Float64], shape: List[Int], c0: Int, c1: Int) raises -> List[Float64]:
    var rows = shape[0]
    var cols = shape[1]
    if c0 < 0 or c1 > cols or c0 >= c1:
        raise Error("slice_cols: out of bounds")
    var out = List[Float64]()
    for r in range(rows):
        for c in range(c0, c1):
            out.append(data[r * cols + c])
    return out^


# 广播加: data(shape) + bdata(bshape), bshape 每维须为 1 或 == shape 同维。
# 输出形状等于 shape。等价 numpy broadcast_add。
def broadcast_add(data: List[Float64], shape: List[Int], bdata: List[Float64], bshape: List[Int]) raises -> List[Float64]:
    if len(shape) != len(bshape):
        raise Error("broadcast_add: rank mismatch")
    for d in range(len(shape)):
        if bshape[d] != 1 and bshape[d] != shape[d]:
            raise Error("broadcast_add: incompatible shape")
    var out = List[Float64]()
    var n = 1
    for d in range(len(shape)):
        n = n * shape[d]
    for i in range(n):
        # 计算 b 的扁平下标: 对每个维, 若 bshape[d]==1 取 0, 否则取 data 同维坐标
        var bidx = 0
        var bstride = 1
        for d in range(len(shape) - 1, -1, -1):
            var cd = _coord_at(i, shape, d)
            var bd = cd if bshape[d] == shape[d] else 0
            bidx = bidx + bd * bstride
            bstride = bstride * bshape[d]
        out.append(data[i] + bdata[bidx])
    return out^

# === core/tests/test_all.mojo ===
# core 模块全量测试聚合器。每个子套件独立 main(), 任一失败则整体非零退出。
import test_number
import test_vector
import test_shuffle
import test_tensor
import test_view
import test_math_ops
import test_math_activate


def main() raises:
    var failed_suites = 0
    print("########## CORE MODULE TEST SUITE ##########")
    try:
        test_number.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_number ->", e)
    try:
        test_vector.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_vector ->", e)
    try:
        test_shuffle.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_shuffle ->", e)
    try:
        test_tensor.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_tensor ->", e)
    try:
        test_view.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_view ->", e)
    try:
        test_math_ops.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_math_ops ->", e)
    try:
        test_math_activate.main()
    except e:
        failed_suites += 1
        print("SUITE FAILED: test_math_activate ->", e)

    if failed_suites > 0:
        print("########## CORE: ", 7 - failed_suites, "/ 7 suites passed,",
              failed_suites, "FAILED ##########")
        raise Error("core test suite had failures")
    print("########## CORE: 7/7 suites passed, ALL GREEN ##########")

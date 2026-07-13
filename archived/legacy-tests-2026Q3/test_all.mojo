# 认知模型 - 全量测试聚合入口
# 运行: .venv/bin/mojo run -I src -I tests tests/test_all.mojo
# 各子套件自带 main() 运行器; 此处逐套件调用, 任一套件失败则整体失败。

import test_bpe
import test_regex
import test_workspace
import test_trigram
import test_wu_xing
import test_liuhe
import test_qixing
import test_executor
import test_taiji
import test_integration_cycle
import test_emoji

def main() raises:
    var failed_suites = 0
    try: test_bpe.main()
    except: failed_suites += 1; print("SUITE FAILED: test_bpe")
    try: test_regex.main()
    except: failed_suites += 1; print("SUITE FAILED: test_regex")
    try: test_workspace.main()
    except: failed_suites += 1; print("SUITE FAILED: test_workspace")
    try: test_trigram.main()
    except: failed_suites += 1; print("SUITE FAILED: test_trigram")
    try: test_wu_xing.main()
    except: failed_suites += 1; print("SUITE FAILED: test_wu_xing")
    try: test_liuhe.main()
    except: failed_suites += 1; print("SUITE FAILED: test_liuhe")
    try: test_qixing.main()
    except: failed_suites += 1; print("SUITE FAILED: test_qixing")
    try: test_executor.main()
    except: failed_suites += 1; print("SUITE FAILED: test_executor")
    try: test_taiji.main()
    except: failed_suites += 1; print("SUITE FAILED: test_taiji")
    try: test_integration_cycle.main()
    except: failed_suites += 1; print("SUITE FAILED: test_integration_cycle")
    try: test_emoji.main()
    except: failed_suites += 1; print("SUITE FAILED: test_emoji")

    if failed_suites > 0:
        raise Error("some test suites failed")
    print("ALL SUITES PASSED")

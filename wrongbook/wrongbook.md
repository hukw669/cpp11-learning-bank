# C++11 错题本与主动提问

## W001：如何利用时间局部性？

**问题：** 如何利用时间局部性？

**核心答案：** 时间局部性是指某个数据或指令刚被访问后，短时间内很可能再次被访问。利用方法是缩短两次访问之间的时间，并让这段时间内使用的数据总量尽量小，使目标仍留在寄存器或各级缓存中。

**常用方法：**

1. 在一次循环或一个处理阶段中连续完成同一批数据的相关操作。
2. 缓存频繁使用的值，避免短时间内重复查表、重复遍历或重新从大对象中读取。
3. 使用分块（blocking/tiling），让当前工作块能够留在缓存中并被反复使用。
4. 合并针对同一数据的多个处理阶段，减少数据离开缓存后再被加载。
5. 控制工作集大小，避免同时访问过多无关数据造成缓存驱逐。
6. 保留真正的热点数据，减少会挤掉热点数据的大范围扫描。

**简单示例：**

```cpp
for (std::size_t i = 0; i < values.size(); ++i) {
    int x = values[i];      // 读取一次
    sum += x;
    squares += x * x;      // 立刻复用 x
}
```

这比先完整计算 `sum`，随后再次遍历整个大数组计算 `squares`，更有机会在同一次加载后复用数据。但是否更快仍取决于数据规模、编译器优化和硬件，应通过基准测试验证。

**与空间局部性的区别：**

- 时间局部性：短时间内重复访问同一个位置。
- 空间局部性：访问一个位置后，接着访问附近位置。

**易错点：** “把数据保存得越久”不是时间局部性；关键是再次使用得足够快，并且中间没有大量其他访问把它逐出缓存。

## W002：各工具链阶段还会出现哪些错误？

**问题：** 预处理、编译和链接还会产生哪些错误？如何完整区分？

**核心答案：** 不同阶段处理的输入和掌握的信息不同，因此能发现的问题不同。预处理器处理指令和记号；编译器检查单个翻译单元的 C++ 规则；汇编器处理汇编代码；链接器组合目标文件并解析符号；装载器检查运行时依赖；程序运行后才会遇到与输入、资源和执行路径有关的问题。

### 1. 预处理阶段

常见问题：

- `#include` 指定的头文件不存在或搜索路径错误。
- `#if`、`#ifdef` 等条件编译缺少匹配的 `#endif`。
- `#include`、`#define` 等指令格式错误。
- 函数式宏的实参数量错误。
- `##` 记号粘贴产生非法预处理记号。
- 源码主动执行 `#error`。
- 递归包含或宏展开超过实现资源限制。

这一阶段尚未按完整 C++ 语法分析普通语句，因此被 `#if 0` 排除的语法错误通常不会进入编译阶段。

### 2. 编译阶段

常见问题：

- 非法记号、字符串或注释未结束。
- 缺少分号、括号不匹配等语法错误。
- 使用未声明的名字或名字查找失败。
- 类型不匹配、非法隐式转换。
- 列表初始化发生禁止的窄化转换。
- 修改 `const` 对象。
- 访问 `private` 或 `protected` 成员不符合规则。
- 找不到匹配的函数重载，或重载调用有二义性。
- 调用了被 `= delete` 删除的函数。
- 模板实参推导或模板实例化失败。
- `static_assert` 条件为假。
- 同一翻译单元中出现不允许的重复定义。
- 声明彼此冲突，例如同一个名字的类型不相容。

编译器通常一次只处理一个翻译单元，所以它能确认“调用处是否看到了正确声明”，但通常不能单独确认其他目标文件最终是否提供了所需定义。

### 3. 汇编阶段

纯标准 C++ 程序较少直接遇到汇编错误，因为汇编代码通常由编译器生成。可能原因包括：

- 内联汇编语法或寄存器写法错误。
- 汇编代码使用了目标 CPU 不支持的指令。
- 编译器、汇编器和目标架构配置不一致。
- 生成文件损坏，或工具链自身存在问题。

内联汇编不是 ISO C++11 的组成部分。

### 4. 链接阶段

常见问题：

- `undefined reference`：声明和调用存在，但没有把相应定义加入链接。
- `multiple definition`：程序中出现不允许并存的多个定义。
- 忘记链接某个静态库或动态库的导入库。
- GNU 风格静态库顺序错误，导致需要的目标成员没有被抽取。
- 声明和定义的函数签名不一致，生成了不同的 C++ 修饰名。
- C 与 C++ 的语言链接约定不一致，例如缺少正确的 `extern "C"` 声明。
- 对象文件或库的架构、位数、对象格式不兼容。
- ABI、运行库或编译选项不一致。
- 需要位置无关代码却没有按要求生成，产生重定位错误。
- 缺少程序入口，例如没有符合要求的 `main`，或平台入口配置错误。
- 声明了虚析构函数等成员，却没有提供其所需定义，可能表现为缺少虚表或类型信息相关符号。

“已有声明”只足以让调用处通过类型检查，不保证链接器一定能找到定义。

### 5. 装载阶段

可执行文件已经链接成功，操作系统启动它时仍可能失败：

- 所需动态库不存在。
- 动态库搜索路径错误。
- 动态库版本或所需符号版本不匹配。
- 可执行文件或动态库的架构不适合当前系统。
- 文件格式损坏或没有执行权限。
- 某个动态库自己的依赖库缺失。

这些问题通常由操作系统的装载器报告，不是 C++ 语法错误。

### 6. 运行阶段

常见情况：

- 输入、文件、网络或其他资源操作失败。
- 动态分配失败并抛出 `std::bad_alloc`。
- 异常没有被合适的处理器捕获，最终调用 `std::terminate`。
- 断言失败。
- 栈空间耗尽、死锁或资源耗尽。
- 程序访问非法地址并被操作系统终止。

其中一些现象可能是未定义行为的外在结果，不能仅根据“程序崩溃”判断根因。

### 7. 逻辑错误

程序能够预处理、编译、链接和运行，但结果不符合需求，例如：

- 循环次数错误。
- 边界条件写错。
- 使用了错误公式。
- 排序方向、业务状态或单位理解错误。

工具链不一定能发现逻辑错误，需要测试、断言、代码审查和运行结果验证。

### 8. 未定义行为

例如：

- 读取未初始化值。
- 数组越界。
- 解引用空指针或悬空指针。
- 有符号整数溢出。
- 除以零。
- 重复释放或释放后使用。
- 对同一对象进行未排序的冲突修改。

未定义行为不保证产生编译错误、链接错误或崩溃；程序可能看似正常，也可能在优化后出现完全不同的结果。

### 9. 警告

警告是编译器或其他工具发现的可疑情况，不是独立的 C++ 标准行为分类。常见警告包括未使用变量、可疑转换、符号比较和可能未初始化。不同工具和警告级别产生的结果不同；将警告视为错误是工程策略，不是 ISO C++11 的统一规定。

### 10. 不属于“错误”的情况

- **实现定义行为：** 实现必须选择并记录一种行为，例如普通 `char` 的有符号性。
- **未指定行为：** 标准允许若干结果，实现不必固定选择，例如 C++11 中许多实参的求值顺序。

二者都不自动表示程序错误，但可移植程序不能随意依赖某个未保证的结果。

## W003：程序、源代码和可执行文件有什么区别？

**问题：** 程序、源代码和可执行文件是同一个东西吗？

**核心答案：** 不是。程序是为完成任务而组织起来的逻辑整体；源代码是程序员用 C++ 等语言写出的文本表示；可执行文件是具体工具链针对某个平台生成的构建产物。

**关键关系：**

- 一个程序通常由多个源文件和头文件共同组成。
- 同一套源代码可以分别生成 Windows、Linux 或不同 CPU 架构的可执行文件。
- 修改源代码不会自动修改已经存在的可执行文件，必须重新构建。
- 删除可执行文件后通常可以使用源代码、依赖库和相同构建配置重新生成；只有可执行文件时，一般不能无损还原原始源代码。
- 程序运行时，操作系统根据可执行文件建立进程；“程序”与“进程”也不是同一概念。

**易错点：** “程序”在日常语境中有时也被用来指可执行文件，但学习编译与链接时应区分逻辑程序、源代码文本、磁盘上的可执行文件和运行中的进程。

## W004：源文件、头文件、目标文件和可执行文件分别做什么？

**问题：** `.cpp` 源文件、头文件、目标文件和可执行文件分别起什么作用？

**核心答案：**

- **源文件：** 通常以 `.cpp` 结尾，存放函数、类等 C++ 声明和定义，是独立翻译的主要起点。
- **头文件：** 通常以 `.h` 或 `.hpp` 结尾，保存需要在多个源文件中共享的声明，以及类、模板、`inline` 函数等适合放在头文件中的定义。普通头文件通常通过 `#include` 被文本纳入源文件，并不是天然独立编译单元。
- **目标文件：** Windows 常见 `.obj`，类 Unix 系统常见 `.o`。它通常包含机器代码、符号表和重定位信息，但可能仍引用其他目标文件或库中的符号，所以一般还不能直接运行。
- **可执行文件：** 链接器把所需目标文件和库组合、解析符号引用后生成的可装载文件；Windows 常见 `.exe`。

**生成关系：**

```text
源文件 + 展开的头文件
        ↓ 预处理、编译、汇编
      目标文件
        ↓ 与其他目标文件、库链接
      可执行文件
        ↓ 操作系统装载
        进程
```

**易错点：**

1. 头文件不是“只放函数定义”的文件，通常主要用于共享声明。
2. `#include` 不是把已经编译好的头文件连接进来，而是在预处理阶段纳入其文本内容。
3. 一个 `.cpp` 通常形成一个翻译单元并产生一个目标文件，但文件扩展名和具体中间产物形式属于工具链约定，不是 ISO C++11 强制规定。
4. 编译成功只说明各翻译单元分别能够生成目标文件；仍可能因为缺少定义、重复定义或库不匹配而链接失败。

## W005：动态库改变后，程序重启会不会报错？

**问题：** 动态库发生改变，原来的可执行程序重新启动时会报错吗？

**核心答案：** 不一定。程序重启后，新进程通常会重新装载当前找到的动态库。是否报错取决于库能否被找到，以及新库是否与原可执行文件所依赖的二进制接口（ABI）兼容。

### 1. 通常可以正常运行

如果只修改了动态库函数内部的实现，同时保持以下内容兼容，原可执行文件一般不需要重新编译或重新链接：

- 动态库文件名及装载路径仍能匹配。
- 原程序使用的导出符号仍然存在。
- 函数参数、返回类型和调用约定不变。
- 类、结构体、虚函数表及对象布局不发生不兼容改变。
- 使用的运行库、异常模型和内存分配规则仍兼容。

程序会使用新动态库中的新实现。这也是动态库能够独立更新的主要价值。

### 2. 程序可能在启动阶段直接失败

常见原因：

- 动态库被删除、改名或不在搜索路径中。
- 原程序需要的导出函数或变量被删除、改名。
- C++ 函数签名改变后，名称修饰产生了不同的符号名。
- 动态库位数或 CPU 架构不匹配。
- 新动态库自己的依赖库缺失。
- 库的版本、运行库或 ABI 不兼容。

隐式链接的动态库通常由装载器在程序启动时处理，因此可能出现“找不到 DLL”“无法打开共享对象”或“找不到指定入口点”等错误。

### 3. 程序可能启动成功，使用相关功能时才失败

可能原因：

- 程序通过 `LoadLibrary`/`GetProcAddress` 或 `dlopen`/`dlsym` 按需加载动态库。
- 平台采用延迟符号绑定，缺失符号到第一次调用时才被解析。
- 导出符号名称没有改变，但参数布局、结构体大小、虚函数顺序或调用约定已经改变。
- 新库改变了行为、数据格式、配置要求或协议。

这时程序可能返回加载失败，也可能产生错误结果、崩溃或未定义行为。ABI 不兼容并不保证得到清晰的报错。

### 4. 为什么不一定需要重新链接？

原可执行文件通常保存“需要哪些动态符号”的信息，函数实现仍在动态库中。启动时，装载器负责找到库并解析这些符号。因此，只要新库继续提供兼容的符号和 ABI，替换库后重启程序即可使用新实现。

如果修改的是静态库，旧的静态库代码已经复制进可执行文件，单独替换静态库不会改变旧程序，必须重新链接。

### 5. 重启与不重启的区别

- **已经运行的进程：** 通常继续使用它启动时已经映射或装载的库代码；简单替换磁盘文件不等于正在运行的进程自动切换到新库。
- **重新启动的进程：** 会重新执行动态库搜索和装载，一般使用届时找到的新库。

具体的文件替换、锁定和装载行为受操作系统影响，不属于 ISO C++11 标准。

**结论表：**

| 动态库变化 | 常见结果 |
|---|---|
| 只改内部实现，ABI 保持兼容 | 正常启动并使用新实现 |
| 库缺失或搜索路径错误 | 启动或加载阶段报错 |
| 删除、改名原有导出符号 | 启动、加载或首次调用时报错 |
| 函数签名或调用约定改变 | 可能找不到符号，也可能运行异常 |
| 结构体、类、虚表布局不兼容 | 可能启动成功，随后崩溃或数据损坏 |
| 仅替换静态库 | 旧可执行文件不变，必须重新链接 |

## W006：`char`、`signed char` 和 `unsigned char` 的符号性有什么用？

**问题：** `char`、`signed char` 和 `unsigned char` 有没有符号？符号性会产生什么影响？

**核心答案：** 它们是三个不同的类型。文本和字符本身没有“正负”的语义；这里的符号性只描述 `char` 中保存的位模式在进入整数运算时如何被解释。`signed char` 明确为有符号整数类型，`unsigned char` 明确为无符号整数类型；普通 `char` 是否具有与 `signed char` 还是 `unsigned char` 相同的值域和表示，由实现决定。即使普通 `char` 表现为有符号，它也仍然不是 `signed char` 类型。

### 0. 为什么文本使用的 `char` 还会谈符号？

C++ 没有一种脱离数值表示的“纯文本基本类型”。`char` 在类型系统中既是字符类型，也是整数类型。字符编码把字符或编码单元映射成整数值，`char` 对象实际保存的仍是一组位。

```cpp
char c = 'A';

std::cout << c;                   // 按字符解释，输出 A
std::cout << static_cast<int>(c); // 按整数解释；ASCII 系统通常输出 65
```

“`char` 可能有符号”并不是说存在“负的字母”，而是说当某个位模式被提升或转换成整数时，结果可能为负。例如在常见八位平台中，保存原始字节 `0xFF` 的普通 `char` 提升为 `int` 后可能得到 `-1`，也可能得到 `255`。

普通 ASCII 字符的编码值位于非负范围内，所以 `'A'` 等基本字符不会因为普通 `char` 的符号性而变成“负字符”。符号差异主要在处理高位为 `1` 的外部编码单元、文件字节或网络数据，并把它们用于算术、比较、索引和字符分类时显现。

标准库使用 `char` 表示窄字符和 `std::string` 的元素，是接口设计和历史约定，不是因为文本需要正负号。

### 1. 值域

三者的 `sizeof` 都是 `1`，但一个字节不一定是八位，位数应通过 `<climits>` 中的 `CHAR_BIT` 获得。

在最常见的 `CHAR_BIT == 8` 实现中：

- `signed char` 通常为 `-128` 到 `127`。
- `unsigned char` 为 `0` 到 `255`。
- 普通 `char` 可能采用上述任意一种值域，取决于编译器和目标平台。

C++11 最低只保证 `signed char` 至少能表示 `-127` 到 `127`，不能仅凭语言标准假定所有平台都采用二进制补码或八位字节。

### 2. 应该怎样选择？

- **普通 `char`：** 用于字符、字符串和文本编码单元，例如 `'A'`、`std::string`。
- **`signed char`：** 用于确实需要负数的小整数；一般不作为普通文本字符类型的替代品。
- **`unsigned char`：** 用于原始字节、二进制缓冲区、位操作以及必须表示完整非负字节值的场景。C++11 尚没有 `std::byte`。

```cpp
char letter = 'A';
signed char temperature = -10;
unsigned char byte = 255;
```

### 3. 符号性会影响哪些行为？

**数值解释不同：** 相同的底层位模式可能被解释为负数或较大的非负数。例如在常见八位实现上，全为 `1` 的位模式常被 `signed char` 解释为 `-1`，被 `unsigned char` 解释为 `255`。

**转换结果不同：** `char`、`signed char` 和 `unsigned char` 参与算术前通常发生整数提升。负的 `char` 或 `signed char` 提升为负的 `int`；`unsigned char` 在常见平台上会提升为保存其原值的 `int`。

**溢出规则不同：**

- `unsigned char` 的转换和算术结果按其无符号范围取模。
- 有符号整数运算若结果超出可表示范围，可能构成未定义行为；不过小整数通常先提升为 `int`，因此需要结合整数提升判断实际参与运算的类型。

**比较和索引不同：** 如果普通 `char` 在某平台上是有符号的，值大于 `127` 的原始字节可能变为负数，用它直接进行数组索引会出现错误甚至越界。

**位操作不同：** 对可能为负的有符号值进行右移或其他位操作会带来实现相关行为和符号扩展问题；处理位模式通常先转换为无符号类型。

### 4. `ctype` 函数的典型陷阱

`std::isalpha`、`std::isdigit` 等函数只接受 `EOF`，或者能够表示为 `unsigned char` 的值。把可能为负的普通 `char` 直接传入可能产生未定义行为：

```cpp
char ch = /* 外部输入 */;

// 错误风险：ch 可能是负数
bool a = std::isalpha(ch);

// 正确
bool b = std::isalpha(static_cast<unsigned char>(ch));
```

### 5. 为什么二进制数据通常使用 `unsigned char`？

- 每一种位模式都对应一个确定的非负值。
- 不会把高位为 `1` 的字节解释为负数。
- C++11 明确允许通过 `char` 或 `unsigned char` 类型查看任意对象的字节表示；实践中 `unsigned char` 更适合表达“原始字节”。

```cpp
unsigned char buffer[1024];
```

**一句话记忆：** 字符没有正负；`char` 的符号性只影响其位模式参与整数运算时的解释。窄字符接口使用 `char`，小型有符号数才用 `signed char`，原始字节和位模式优先用 `unsigned char`。

## W007：为什么 `void*` 不能隐式转回 `int*`？

**问题：** 为什么下面最后一行不符合 C++11？不学习新的强制转换语法时，怎样最小纠正？

```cpp
int value = 3;
void* erased = &value;
int* restored = erased;
```

**核心答案：** `void*` 是可以保存对象地址的通用对象指针，但它不记录所指对象的具体静态类型。C++11 允许具体对象指针隐式转换为保持 cv 限定的 `void*`，却不允许反方向的隐式转换，因为编译器无法仅根据一个 `void*` 判断它原来是否真的指向 `int`。

### 1. 正向转换为什么允许？

```cpp
int value = 3;
int* original = &value;
void* erased = original;
```

这里没有改变所指对象，也没有把 `value` 转换成 `void`。只是把“指向 `int` 的地址”保存到一个不携带具体对象类型信息的指针变量中。

转换后：

- `erased` 仍保存 `value` 的地址。
- `value` 仍然是 `int`。
- `erased` 的静态类型只有 `void*`。
- 不能写 `*erased`，因为编译器不知道要按什么类型和大小访问内存。
- ISO C++11 不支持直接对 `void*` 做指针算术。

### 2. 为什么不能自动转换回来？

下面三个指针都能隐式转换成 `void*`：

```cpp
int i = 3;
double d = 2.5;
long n = 8;

void* p1 = &i;
void* p2 = &d;
void* p3 = &n;
```

只看一个 `void*` 变量，编译器无法知道它来自 `int*`、`double*` 还是 `long*`。如果允许自动转换：

```cpp
int* wrong = p2; // p2 实际指向 double
```

错误类型就会悄悄通过检查。C++ 因此要求程序员显式承担恢复类型的责任。

### 3. 不学习强制转换时怎样纠正？

如果原来的具体指针仍然可用，可以完全避免恢复：

```cpp
int value = 3;
int* original = &value;
void* erased = original;
int* restored = original;
```

本题的最小编译修正也可以写成：

```cpp
int* restored = &value;
```

但这只是绕过 `erased`，并不是真正“从 `void*` 恢复”。如果程序手中只剩下 `erased`，又必须恢复为 `int*`，就需要显式转换：

```cpp
int* restored = static_cast<int*>(erased);
```

只有当 `erased` 确实来自相容的 `int*` 时，才能通过 `restored` 正确访问原对象。显式转换只表达程序员的判断，不会在运行时自动验证真实类型。

### 4. cv 限定不能被偷偷删除

```cpp
const int value = 3;
const void* erased = &value; // 正确：保留 const
```

不能把 `const int*` 隐式转换成 `void*`，因为那会丢掉 `const`。对应关系应当是：

```text
int*             → void*
const int*       → const void*
volatile int*    → volatile void*
```

### 5. `void*` 不是“空指针”

名字中的 `void` 不表示“地址为空”：

```cpp
int value = 3;
void* p = &value; // p 非空
void* q = nullptr; // q 才是空指针
```

`void*` 表示“未指定具体对象类型的地址”；`nullptr` 表示“不指向对象或函数的空指针值”，二者不是同一概念。

**一句话记忆：** 具体对象指针转成 `void*` 是擦除静态类型；从 `void*` 转回来需要程序员明确指定类型，而且程序员必须保证指定正确。

## W008：`enum class` 是什么？

**问题：** C++11 中的 `enum class` 是什么？它与传统 `enum` 有什么区别？

**核心答案：** `enum class` 是 C++11 引入的有作用域枚举，也称强类型枚举。它用于定义一组有限的、具有名字的取值。枚举项必须通过枚举类型名访问，不会自动转换为整数，不同枚举类型之间也不能随意混用。

### 1. 基本写法

```cpp
enum class Direction {
    up,
    down,
    left,
    right
};

Direction direction = Direction::left;
```

`Direction` 是一个新类型，`up`、`down` 等是该类型可以使用的具名枚举值。默认情况下，第一个未显式指定的枚举值为 `0`，之后依次加 `1`。

```cpp
enum class Status {
    success = 0,
    busy = 3,
    failed = 10
};
```

### 2. 枚举项具有自己的作用域

```cpp
enum class Color {
    red,
    green
};

Color color = Color::red; // 正确
// Color color = red;     // 错误：red 不在外部作用域
```

因此不同枚举可以安全地使用相同枚举项名字：

```cpp
enum class TrafficLight { red, green };
enum class InkColor     { red, green };

TrafficLight light = TrafficLight::red;
InkColor ink = InkColor::red;
```

### 3. 不会隐式转换为整数

```cpp
enum class Error {
    none = 0,
    timeout = 1
};

Error error = Error::timeout;

// int n = error; // 错误
int n = static_cast<int>(error); // 明确需要整数值时显式转换
```

这可以避免把状态枚举误当成普通数字参与运算、比较或传给错误接口。

### 4. 不同枚举类型不能混用

```cpp
enum class Color { red, green };
enum class State { ready, stopped };

Color color = Color::red;
State state = State::ready;

// color = state;          // 错误：类型不同
// color == State::ready;  // 错误：类型不同
```

即使两个枚举的底层整数值相同，它们仍然代表不同的业务概念。

### 5. 可以指定底层整数类型

```cpp
enum class PacketType : unsigned char {
    login = 1,
    data = 2,
    logout = 3
};
```

冒号后的 `unsigned char` 是底层类型，决定枚举值可表示范围以及枚举对象的底层表示特征。没有显式指定时，有作用域枚举的底层类型默认为 `int`。

所有枚举值都必须能由底层类型表示：

```cpp
enum class Small : unsigned char {
    value = 300 // 错误：常见八位 unsigned char 无法表示 300
};
```

### 6. 在 `switch` 中使用

```cpp
enum class State {
    ready,
    running,
    stopped
};

State state = State::running;

switch (state) {
case State::ready:
    break;
case State::running:
    break;
case State::stopped:
    break;
}
```

`case` 标签同样要写完整的 `State::` 限定。

### 7. 与传统 `enum` 对比

```cpp
enum OldColor {
    red,
    green
};

enum class NewColor {
    red,
    green
};
```

| 特性 | 传统 `enum` | `enum class` |
|---|---|---|
| 枚举项作用域 | 通常进入外围作用域 | 保留在枚举类型作用域 |
| 使用方式 | `red` | `NewColor::red` |
| 隐式转为整数 | 通常可以 | 不可以 |
| 不同枚举误混用风险 | 较高 | 较低 |
| 类型安全性 | 较弱 | 较强 |

### 8. 常见误区

- `enum class` 不是普通的 `class`，不能随意在其中定义成员函数和成员变量。
- 它不会自动把枚举项转换成字符串，`Color::red` 不等于字符串 `"red"`。
- 它不会自动提供 `|`、`&` 等位运算符；用作位标志时需要自行设计运算符。
- `enum struct` 与 `enum class` 在这里含义相同。

**一句话记忆：** `enum class` 把一组有限状态封装成独立类型，使用 `类型名::枚举项`，并阻止枚举值被随意当作整数或其他枚举类型使用。

## W009：同一个源文件能否多次写 `int x;`？

**问题：** 同一个源文件不可以多次写 `int x;` 吗？

**核心答案：** 不能只看是否位于同一个源文件，必须看作用域和这些声明是否定义同一个实体。同一作用域中的两个 `int x;` 是对同一名字的重复定义，不合法；同一源文件中位于不同函数或嵌套作用域的同名局部变量是不同对象，可以存在。

```cpp
void f()
{
    int x;
    // int x; // 错误：同一作用域重复定义

    {
        int x; // 正确：新的内层作用域，遮蔽外层 x
    }
}

void g()
{
    int x; // 正确：这是 g 中的另一个局部对象
}
```

在命名空间作用域，`int x;` 也是定义：

```cpp
int x;
// int x; // 错误：同一翻译单元中重复定义
```

可以多次写相容的非定义声明，但只能提供一次定义：

```cpp
extern int x;
extern int x;
int x = 0; // 唯一定义
```

跨文件共享变量的 C++11 常见组织方式：

```cpp
// counter.h
extern int counter;
```

```cpp
// counter.cpp
#include "counter.h"
int counter = 0;
```

各使用方包含头文件。不要在普通头文件中直接放 `int counter;`，否则多个翻译单元通常会各自产生一个外部定义，违反单一定义规则。

**一句话记忆：** “同一个文件”不是判断标准；同一作用域不能重复定义同一对象，不同作用域可以有同名的不同对象，相容的 `extern` 声明可以重复。

## W010：什么时候需要拷贝构造函数？

**问题：** 什么时候会使用拷贝构造函数？什么时候需要程序员自己编写？

**核心答案：** 拷贝构造函数用一个已有的同类型对象来创建一个新对象，典型形式是 `T(const T&)`。每个可拷贝类都需要具有可用的拷贝构造语义，但通常由编译器隐式生成；只有默认的逐成员复制不符合类的资源所有权或不变量要求时，才需要自己编写。若对象根本不应复制，应使用 `= delete` 禁止复制。

### 1. 基本形式

```cpp
class Student {
public:
    Student() : score(0) {}

    Student(const Student& other)
        : name(other.name), score(other.score)
    {
    }

private:
    std::string name;
    int score;
};
```

参数通常写成 `const T&`：

- 使用引用避免为了传入参数而再次复制对象。
- 使用 `const` 允许复制常量对象，并承诺不修改来源对象。

### 2. 哪些场景可能使用拷贝构造函数？

**用已有对象初始化新对象：**

```cpp
Student a;
Student b = a;
Student c(a);
```

`b`、`c` 都是新对象，因此这里讨论的是拷贝构造。

**按值传递左值实参：**

```cpp
void print(Student value);

Student a;
print(a);
```

形参 `value` 是一个新对象，通常需要从 `a` 复制构造。若函数只读取对象，一般使用 `const Student&` 避免复制：

```cpp
void print(const Student& value);
```

**按值返回、抛出和捕获对象：**

```cpp
Student make_student();
throw a;
catch (Student value) {
}
```

这些语境可能涉及复制。不过 C++11 允许编译器进行复制消除，返回局部对象时还可能使用移动构造，因此不能仅凭源码形式断言运行时一定实际调用了几次拷贝构造函数。

**把左值放入标准容器：**

```cpp
std::vector<Student> students;
Student a;
students.push_back(a);
```

这里容器需要创建自己的元素，通常从左值 `a` 复制构造。传入右值时可能改用移动构造。

### 3. 拷贝构造和拷贝赋值不同

```cpp
Student a;
Student b = a; // b 正在创建：拷贝构造

Student c;
c = a;         // c 已经存在：拷贝赋值
```

判断方法：

- 新对象正在诞生：构造。
- 对象已经存在，随后写 `=`：赋值。

声明中的 `=` 不一定代表赋值，`Student b = a;` 仍是初始化。

### 4. 什么时候不需要自己写？

如果每个成员本身都具有正确的复制语义，编译器生成的逐成员复制通常已经正确：

```cpp
class Student {
    std::string name;
    std::vector<int> scores;
};
```

编译器生成的拷贝构造函数会复制 `name` 和 `scores`；`std::string`、`std::vector` 会管理自己的资源，因此通常不需要手写拷贝构造、析构和赋值函数。这称为 Rule of Zero（零法则）。

### 5. 什么时候需要自己设计？

**类直接拥有裸指针资源，并且复制应产生独立资源：**

```cpp
class Buffer {
public:
    explicit Buffer(std::size_t count)
        : size(count), data(new int[count]{})
    {
    }

    ~Buffer()
    {
        delete[] data;
    }

    Buffer(const Buffer& other)
        : size(other.size),
          data(new int[other.size])
    {
        std::copy(other.data, other.data + size, data);
    }

    Buffer& operator=(const Buffer&) = delete; // 此处只演示拷贝构造

private:
    std::size_t size;
    int* data;
};
```

编译器默认只会复制指针地址，使两个对象指向同一块内存，容易造成相互影响和重复释放。若需要“深拷贝”，必须定义适当的资源复制行为。上例为了只聚焦拷贝构造而删除了拷贝赋值；一个完整的可赋值资源类还必须正确实现赋值和移动。实际代码更推荐直接使用 `std::vector<int>`、`std::string` 或智能指针表达所有权。

**复制时必须维护特殊不变量：**

- 每个副本需要新的唯一编号。
- 缓存、注册信息或引用计数需要特殊处理。
- 操作系统资源句柄需要复制、共享或者重新打开。

这时必须先明确“复制这个对象”在业务上的含义。

### 6. 什么时候应禁止拷贝？

文件、套接字、互斥锁和独占资源对象通常不能简单复制：

```cpp
class Socket {
public:
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
};
```

使用 `std::unique_ptr` 成员时，类的隐式拷贝操作通常也会被删除，因为独占所有权不能直接复制。这类对象可以根据设计支持移动。

### 7. 三法则与五法则

如果类需要自己管理资源，并且必须手写以下任意操作，应一起检查其他操作是否也需要设计：

- 析构函数。
- 拷贝构造函数。
- 拷贝赋值运算符。

这是三法则。C++11 加入移动语义后，还要检查：

- 移动构造函数。
- 移动赋值运算符。

合起来称为五法则。更优先的设计仍然是使用标准资源管理类型，让编译器生成这些操作。

**一句话记忆：** 用旧对象创建新对象时需要拷贝构造语义；成员都能正确复制时让编译器生成，拥有特殊资源时明确设计深拷贝、共享或禁用复制。

## W011：直接初始化、拷贝初始化、列表初始化和聚合初始化

**问题：** 直接初始化、拷贝初始化、列表初始化和聚合初始化分别是什么？它们是什么关系？

**核心答案：** 四者不是互斥的平行分类。直接初始化和拷贝初始化描述初始化语境；列表初始化表示使用 `{}`；列表初始化又分直接列表初始化和拷贝列表初始化。目标是聚合类型时，列表初始化进一步采用聚合初始化规则。

| 写法 | 分类 |
|---|---|
| `T a(x);` | 直接初始化，非列表初始化 |
| `T a = x;` | 拷贝初始化，非列表初始化 |
| `T a{x};` | 直接列表初始化 |
| `T a = {x};` | 拷贝列表初始化 |
| `Point p{1, 2};` | 直接列表初始化；若 `Point` 是聚合，同时也是聚合初始化 |
| `Point p = {1, 2};` | 拷贝列表初始化；若 `Point` 是聚合，同时也是聚合初始化 |

### 1. 直接初始化

```cpp
int number(3);
Student copy(original);
```

直接初始化会直接为目标对象选择可用构造函数，并且可以使用 `explicit` 构造函数：

```cpp
class Meter {
public:
    explicit Meter(double value);
};

Meter meter(2.5); // 正确
```

“直接初始化”不表示“绝对不会复制”。`Student copy(original);` 是直接初始化语法，但可以调用拷贝构造函数。

注意最令人烦恼的解析：

```cpp
Student object(); // 函数声明，不是创建对象
Student object{}; // 创建对象
```

### 2. 拷贝初始化

```cpp
int number = 3;
Student copy = original;
```

声明中的 `=` 不是赋值，因为对象尚未存在。拷贝初始化也不保证一定调用拷贝构造函数：

```cpp
class Number {
public:
    Number(int);
};

Number number = 5; // 使用 Number(int) 建立对象
```

它还可能使用移动构造，或者在 C++11 允许的场景中发生复制消除。“拷贝初始化”是语言规则名称，不是运行时复制次数保证。

### 3. 列表初始化

```cpp
int a{3};      // 直接列表初始化
int b = {3};   // 拷贝列表初始化
int array[4]{1, 2}; // 后两个元素为 0
```

列表初始化的重要特性是禁止部分窄化转换：

```cpp
int a = 3.14;   // 合法，得到 3
int b(3.14);    // 合法，得到 3
int c{3.14};    // 错误：窄化
int d = {3.14}; // 错误：窄化
```

直接列表初始化可以使用 `explicit` 构造函数；拷贝列表初始化如果最终选择了 `explicit` 构造函数，则程序不合法：

```cpp
Meter a{2.5};    // 正确
Meter b = {2.5}; // 错误
```

花括号还会优先考虑匹配的 `std::initializer_list` 构造函数：

```cpp
std::vector<int> a(10, 20); // 10 个元素，每个值为 20
std::vector<int> b{10, 20}; // 两个元素：10、20
```

花括号本身不等于 `std::initializer_list`；只有重载决议实际选择相应构造函数时才使用该类型。

### 4. 聚合初始化

C++11 中，数组属于聚合。类要成为聚合，需满足没有用户提供的构造函数、没有类内非静态成员初始化器、没有私有或受保护的非静态数据成员、没有基类并且没有虚函数等要求。

```cpp
struct Point {
    int x;
    int y;
};

Point a{10, 20};
Point b = {10, 20};
```

`a` 和 `b` 都进行聚合初始化，成员按照声明顺序获得初始化值。初始化项不足时，其余成员按空初始化列表规则初始化：

```cpp
Point p{10}; // p.x 为 10，p.y 为 0
```

初始化项过多则不合法：

```cpp
Point p{1, 2, 3}; // 错误
```

严格 C++11 中，聚合不能使用圆括号逐成员初始化，也没有 C++20 的指定成员初始化：

```cpp
Point a(1, 2);          // C++11 错误：没有相应构造函数
Point b{.x = 1, .y = 2}; // 不是 ISO C++11
```

### 5. 与赋值的区别

```cpp
Student a;
Student b = a; // 初始化：b 正在开始生命周期
b = a;         // 赋值：b 已经存在
```

判断标准不是有没有 `=`，而是目标对象是否正在建立。

**一句话记忆：** 圆括号和 `=` 区分常见直接/拷贝初始化语境，花括号表示列表初始化；若花括号的目标是聚合，它又同时执行聚合初始化。

## W012：`int&` 是什么类型？

**问题：** `auto&& a = value;` 推导后为什么得到 `int&`？`int&` 是什么类型？

**核心答案：** `int&` 是“到 `int` 的左值引用类型”。引用为已有对象提供别名；通过引用读取或修改，实际操作的是被引用对象。

```cpp
int value = 1;
int& alias = value;

alias = 10; // value 同时变成 10
```

`alias` 不是 `value` 的副本。修改引用不会改变引用的绑定目标，而是修改原对象；引用初始化后不能重新绑定到另一个对象。

### 1. 为什么 `auto&& a = value` 得到 `int&`？

```cpp
int value = 1;
auto&& a = value;
```

虽然 `value` 的声明类型是 `int`，但表达式 `value` 是左值。这里的 `auto&&` 发生类型推导，属于转发引用形式：

```text
初始化器是 int 左值
→ auto 推导为 int&
→ auto&& 代入后得到 int& &&
→ 引用折叠为 int&
```

引用折叠的核心规则是：组合中只要出现左值引用 `&`，结果就是左值引用；只有 `&&` 与 `&&` 组合才得到 `&&`。

### 2. 为什么 `auto&& b = 3` 得到 `int&&`？

```cpp
auto&& b = 3;
```

`3` 是 `int` 类型的纯右值，`auto` 推导为 `int`，代入后就是 `int&&`。右值引用可以绑定这个临时结果，并把临时对象的生命周期延长到局部引用 `b` 的生命周期结束。

### 3. 左值引用的基本限制

```cpp
int value = 1;
const int fixed = 2;

int& a = value;       // 正确
// int& b = fixed;    // 错误：会丢掉 const
// int& c = 3;        // 错误：普通左值引用不能绑定纯右值
const int& d = fixed; // 正确
const int& e = 3;     // 正确
```

### 3.1 非常量引用与常量引用的完整对比

```cpp
int value = 1;
const int fixed = 2;

int& a = value;
const int& b = value;
const int& c = fixed;
const int& d = 3;
```

四个声明都合法，但绑定含义不同：

| 引用 | 最终类型 | 绑定对象 | 能否通过引用修改 |
|---|---|---|---:|
| `a` | `int&` | 可修改对象 `value` | 可以 |
| `b` | `const int&` | 可修改对象 `value` | 不可以 |
| `c` | `const int&` | 常量对象 `fixed` | 不可以 |
| `d` | `const int&` | 为纯右值 `3` 产生的临时对象 | 不可以 |

`const int& b = value;` 只限制通过 `b` 修改，不会把 `value` 永久变成常量：

```cpp
value = 10; // 正确
```

之后通过 `b` 读取到的也是 `10`，因为 `b` 仍引用同一个 `value`：

```cpp
// b = 20; // 错误：不能通过 const int& 修改
```

`const int& d = 3;` 会把为绑定而产生的临时整数生命周期延长到局部引用 `d` 的生命周期结束：

```cpp
{
    const int& d = 3;
    // 在此作用域内 d 可安全读取
}
// 离开作用域后，临时对象和引用 d 的生命周期结束
```

不能把这条规则误用为“所有临时对象引用都安全”。例如从函数返回一个绑定到局部临时对象的引用，仍可能形成悬空引用。

常量引用还可能绑定到经过类型转换产生的临时对象：

```cpp
double number = 3.8;
const int& reference = number;
```

这里 `reference` 不是引用 `number` 本身，而是引用由 `3.8` 转换得到的临时 `int`，其值为 `3`。之后修改 `number` 不会改变 `reference` 读到的值。

### 4. 具名右值引用变量本身是左值表达式

```cpp
auto&& b = 3; // b 的声明类型是 int&&
```

但随后单独写表达式 `b` 时，`b` 是有名字的变量，因此表达式 `b` 是左值。声明类型和值类别是两个不同概念。

**一句话记忆：** `int&` 是已有 `int` 对象的左值引用；`auto&&` 遇到左值时通过推导和引用折叠变成 `int&`，遇到右值时才得到 `int&&`。

## W013：`decltype` 是什么？

**问题：** C++11 中的 `decltype` 是什么？它怎样确定类型？

**核心答案：** `decltype` 是 C++11 的类型说明符，用来在编译期取得一个名字或表达式对应的类型。它的操作数通常不会被执行。对未加括号的名字采用“取得声明类型”的特殊规则；对其他表达式，则根据表达式的值类别决定得到 `T`、`T&` 还是 `T&&`。

### 1. 基本写法

```cpp
int value = 1;
decltype(value) another = 2;
```

`value` 声明为 `int`，所以 `decltype(value)` 是 `int`，等价于：

```cpp
int another = 2;
```

`decltype` 得到的是类型，自己不会创建对象；只有把得到的类型放进声明中，才会定义变量。

### 2. 未加括号名字的特殊规则

当操作数是未加括号的变量名时，`decltype` 直接得到该实体声明时的类型，包括引用和 `const`：

```cpp
int value = 1;
const int fixed = 2;
int& alias = value;

decltype(value) a = 3; // int
decltype(fixed) b = 4; // const int
decltype(alias) c = value; // int&
```

### 3. 一般表达式规则

如果没有命中“未加括号名字”的特殊规则，则根据表达式值类别判断：

```text
左值表达式   → T&
将亡值表达式 → T&&
纯右值表达式 → T
```

例如：

```cpp
int value = 1;

decltype((value)) a = value; // int&，因为 (value) 是左值
decltype(value + 1) b = 2;   // int，因为 value + 1 是纯右值
```

### 4. 为什么括号会改变结果？

```cpp
int value = 1;

decltype(value) copy = 2;      // int
decltype((value)) alias = value; // int&
```

`decltype(value)` 命中名字特殊规则，得到声明类型 `int`；额外括号使其按一般表达式处理，而 `(value)` 是左值，所以得到 `int&`。

这是 `decltype` 最重要的易错点之一。

### 4.1 `decltype((value))` 得到的是变量本身吗？

不是。`decltype` 的结果始终是一个类型，不会返回对象、变量或运行期数值。

```cpp
int value = 1;

decltype(value) copy = 2;
decltype((value)) alias = value;
```

等价理解：

```cpp
int copy = 2;
int& alias = value;
```

这里：

- `value` 是一个变量或对象。
- `int` 是 `value` 的声明类型。
- 表达式 `value` 是左值。
- `decltype(value)` 使用名字特殊规则，结果为 `int`。
- `decltype((value))` 使用一般表达式规则，结果为 `int&`。

所以准确说法不是“`decltype((value))` 的类型是 `value` 变量”，而是：

> `(value)` 是一个类型为 `int` 的左值表达式，因此 `decltype((value))` 得到左值引用类型 `int&`。

得到引用类型后，用它声明的变量可以成为 `value` 的别名：

```cpp
alias = 10; // 实际修改 value
```

如果原变量是常量：

```cpp
const int value = 1;

decltype(value) copy = 2;          // const int
decltype((value)) alias = value;   // const int&
```

如果变量本身声明为右值引用，额外括号仍会体现“有名字的表达式是左值”：

```cpp
int&& reference = 3;

decltype(reference) a = 4;          // int&&：名字特殊规则
decltype((reference)) b = reference; // int&：一般表达式规则
```

### 5. 操作数通常不执行

```cpp
int i = 0;
decltype(i++) result = 0;
```

`i++` 用于分析类型和值类别，但不会真正执行，因此 `i` 仍为 `0`。不过表达式仍然必须语法正确并且能够通过类型检查。

### 6. 与 `auto` 的区别

```cpp
const int value = 3;

auto a = value;        // int，普通按值 auto 丢弃顶层 const
decltype(value) b = 4; // const int，保留声明类型
```

普通 `auto` 根据初始化器推导变量类型，并通常丢弃引用和顶层 `const`；`decltype` 检查指定名字或表达式，并按照自己的规则保留或产生引用。

### 7. C++11 的典型用途

当返回类型依赖参数表达式时，可以使用尾置返回类型：

```cpp
template<class T, class U>
auto add(T left, U right) -> decltype(left + right)
{
    return left + right;
}
```

C++11 中，函数名前面的 `auto` 表示真正的返回类型写在 `->` 后；`decltype(left + right)` 根据加法表达式确定返回类型。

### 8. 版本边界

`decltype` 属于 C++11，但 `decltype(auto)` 是 C++14 引入的写法，严格 C++11 代码不能使用：

```cpp
// decltype(auto) result = expression; // 不是 C++11
```

**一句话记忆：** `decltype(name)` 通常取得名字的声明类型；`decltype((expression))` 等一般形式根据值类别得到 `T`、`T&` 或 `T&&`，并且只分析表达式而不执行它。

## W014：什么是将亡值，为什么 `decltype` 得到 `T&&`？

**问题：** `decltype` 规则中的“将亡值 → T&&”是什么意思？

**核心答案：** 将亡值（xvalue）是 C++11 的表达式值类别，不是对象类型。它指代一个仍然存在的对象，但表达式表示该对象的资源可以被移动操作复用。对一般表达式使用 `decltype` 时，如果表达式是 `T` 类型的将亡值，结果就是右值引用类型 `T&&`。

### 1. 类型和值类别不是一回事

```cpp
int value = 1;
```

- `value` 对象的类型是 `int`。
- 单独写表达式 `value` 时，它是左值。
- 写 `std::move(value)` 时，表达式是将亡值。
- `int&&` 是右值引用类型。

所以“将亡值”描述表达式怎样指代对象，`T&&` 描述引用的类型。

### 2. 三种常见表达式

```cpp
int value = 1;

value;             // 左值：指代一个有名字、可定位的对象
3;                 // 纯右值：产生一个值
std::move(value);  // 将亡值：仍指代 value，但允许移动其资源
```

简化对比：

| 表达式类别 | 是否指代已有对象 | 典型例子 |
|---|---|---|
| 左值 | 是 | `value` |
| 纯右值 | 通常用于产生值 | `3`、`a + b` |
| 将亡值 | 是，但可被当作资源来源 | `std::move(value)` |

将亡值既属于泛左值，因为它指代对象；也属于右值，因为它可以绑定到右值引用并参与移动。

### 2.1 C++11 的完整值类别关系

C++11 有五个值类别名称，但其中只有三个是互斥的基础类别：

```text
基础类别：
左值   lvalue
将亡值 xvalue
纯右值 prvalue

组合类别：
泛左值 glvalue = 左值 + 将亡值
右值   rvalue  = 将亡值 + 纯右值
```

因此不能把“左值、右值、将亡值”理解成三个并列类别，因为将亡值本身属于右值。它同时属于泛左值和右值：

- 属于泛左值：它仍然指代一个具有身份、能够定位的对象。
- 属于右值：它允许绑定右值引用，并可作为移动操作的资源来源。

完整对比：

| 类别 | 核心含义 | 例子 |
|---|---|---|
| 左值 `lvalue` | 指代有身份的对象，通常不默认放弃资源 | `value`、`*pointer` |
| 将亡值 `xvalue` | 指代有身份的对象，但允许复用资源 | `std::move(value)` |
| 纯右值 `prvalue` | 主要用于计算或产生一个值 | `3`、`a + b` |
| 泛左值 `glvalue` | 所有具有对象身份的表达式 | 左值和将亡值 |
| 右值 `rvalue` | 纯右值和可移动的将亡值 | 纯右值和将亡值 |

常见引用绑定关系：

| 引用类型 | 通常可以绑定 |
|---|---|
| `T&` | 可修改左值 |
| `const T&` | 左值、将亡值、纯右值 |
| `T&&` | 将亡值、纯右值 |

```cpp
int value = 1;

int& a = value;             // value 是左值
const int& b = 3;           // 3 是纯右值
int&& c = 3;                // 纯右值绑定右值引用
int&& d = std::move(value); // 将亡值绑定右值引用
```

### 3. `std::move` 不会自己移动对象

```cpp
#include <string>
#include <utility>

std::string source = "hello";
std::string target = std::move(source);
```

`std::move(source)` 只是把表达式转换成将亡值，使移动构造函数成为可选项。真正转移字符串资源的是 `std::string` 的移动构造函数。

移动后：

- `source` 对象仍然活着。
- 它仍然必须能够安全析构和重新赋值。
- 它的具体内容通常处于有效但未指定状态。

所以“将亡”不表示对象已经销毁，也不保证它马上销毁。

### 4. 为什么 `decltype` 得到 `T&&`？

对没有命中“未加括号名字”特殊规则的一般表达式：

```text
左值表达式   → decltype 得到 T&
将亡值表达式 → decltype 得到 T&&
纯右值表达式 → decltype 得到 T
```

例如：

```cpp
#include <utility>

int value = 1;
decltype(std::move(value)) reference = 2;
```

`std::move(value)` 是 `int` 类型的将亡值，所以：

```cpp
decltype(std::move(value))
```

得到：

```cpp
int&&
```

### 5. 有名字的右值引用变量仍是左值表达式

```cpp
int&& reference = 3;
```

`reference` 的声明类型是 `int&&`，但表达式 `reference` 有名字，所以它是左值：

```cpp
decltype(reference)   a = 4;         // int&&：名字特殊规则
decltype((reference)) b = reference; // int&：一般表达式规则
```

如果要再次把它作为将亡值使用，需要：

```cpp
std::move(reference)
```

**一句话记忆：** 将亡值是“仍指向现有对象、但允许复用其资源”的表达式；`std::move(x)` 是典型将亡值，因此一般 `decltype` 规则得到 `T&&`。

## W015：将亡值周围还有哪些关联知识点？

**问题：** 与将亡值、`T&&` 和 `decltype` 类似或紧密关联的知识点还有什么？

**核心答案：** 这些概念组成一条连续知识链：表达式值类别决定引用绑定和重载选择；类型推导与引用折叠决定最终引用类型；`std::move` 和 `std::forward` 改变或保留表达式值类别；移动构造、资源所有权、异常保证和对象生存期决定这些工具是否安全。

推荐按以下顺序学习：

1. **表达式与值类别：** 左值、纯右值、将亡值、泛左值和右值。
2. **引用绑定：** `T&`、`const T&`、`T&&` 分别能绑定什么。
3. **类型推导：** `auto`、`auto&`、`auto&&` 和 `decltype`。
4. **引用折叠：** `T& &&` 为什么折叠为 `T&`。
5. **转发引用：** 模板参数推导中的 `T&&` 与普通右值引用的区别。
6. **`std::move`：** 无条件把表达式转换成可移动形式，但不执行资源移动。
7. **移动构造和移动赋值：** 对象怎样接管资源，源对象留下什么状态。
8. **`std::forward`：** 在泛型代码中保留调用者原来的左值或右值性质。
9. **完美转发：** 转发引用、引用折叠和 `std::forward` 的组合。
10. **重载决议：** `f(const T&)` 与 `f(T&&)` 分别在什么时候被选择。
11. **临时对象生命周期：** `const T&`、局部 `T&&` 的生命周期延长和悬空引用风险。
12. **特殊成员函数：** 拷贝/移动构造、拷贝/移动赋值、析构函数及五法则、零法则。
13. **`noexcept`：** 标准容器为何可能只在移动构造不抛异常时选择移动。
14. **复制消除：** C++11 允许省略部分复制或移动，但不能套用 C++17 的强制规则。
15. **成员函数引用限定符：** 成员函数后的 `&`、`&&` 怎样限制调用对象的值类别。

最常见的连续误区：

```text
变量的类型是 T&&
≠ 这个变量名表达式是右值

调用 std::move
≠ 已经发生资源移动

出现 T&&
≠ 一定是转发引用

使用移动构造
≠ 源对象已经销毁

拷贝初始化
≠ 一定调用拷贝构造函数
```

**一句话记忆：** 先学值类别和引用绑定，再学 `auto`/`decltype`，随后学习 `move`、移动构造，最后进入引用折叠、`forward` 和完美转发。

## W016：`auto` 只能推导基本类型吗？

**问题：** 普通 `auto` 是否只包含或只保留基本变量类型？为什么 `auto a = original;` 和 `auto b = alias;` 都得到 `int`？

**核心答案：** 不是。`auto` 是编译期类型推导占位符，可以推导基本类型、类类型、指针、迭代器、函数指针和 Lambda 闭包类型等。题目中的 `a`、`b` 得到 `int`，是因为没有配合 `&` 的普通按值 `auto` 会建立新对象，并通常去掉初始化器类型中的引用和顶层 `const`。

### 1. `auto` 可以推导很多类型

```cpp
#include <string>
#include <vector>

auto number = 3;                       // int
auto text = std::string("hello");      // std::string
auto pointer = &number;                // int*
auto values = std::vector<int>{1, 2};  // std::vector<int>
auto iterator = values.begin();        // std::vector<int>::iterator
auto function = [](int x) { return x + 1; }; // 某个闭包类型
```

Lambda 的闭包类型没有可直接写出的普通类型名，因此 `auto` 特别适合保存 Lambda。

### 2. 原题为什么得到两个 `int`？

```cpp
const int original = 7;
const int& alias = original;

auto a = original;
auto b = alias;
```

推导结果：

```text
a：int
b：int
```

`auto a = original;` 按值读取 `original` 并创建独立对象，去掉 `original` 自身的顶层 `const`。

`auto b = alias;` 同样按值创建独立对象。引用不是被复制到 `b` 中；程序读取 `alias` 所引用的整数值，并以该值初始化新的 `int` 对象。

因此：

```cpp
a = 10; // 正确，只修改 a
b = 20; // 正确，只修改 b
```

`original` 仍然是 `7`。

### 3. 想保留引用要明确写 `&`

```cpp
auto& a = original;       // const int&
auto& b = alias;          // const int&
const auto& c = original; // const int&
```

这里 `a`、`b`、`c` 都引用 `original`，没有创建整数副本；由于原对象为 `const int`，不能通过这些引用修改它。

### 4. 普通 `auto` 去掉的是顶层 `const`

顶层 `const` 修饰变量自身：

```cpp
const int value = 3;
auto copy = value; // int
```

底层 `const` 是所指对象类型的一部分，通常会保留：

```cpp
const int value = 3;
const int* pointer = &value;

auto copy = pointer; // const int*
```

`copy` 指针变量本身可以改变指向，但不能通过它修改所指的 `const int`。

再看指针自身为常量的情况：

```cpp
int value = 3;
int* const fixed_pointer = &value;

auto pointer = fixed_pointer; // int*，去掉指针自身的顶层 const
```

### 5. `auto` 不是动态类型

```cpp
auto value = 3; // 编译期确定为 int

value = 5;      // 正确
// value = "hello"; // 错误：value 不会在运行时变成字符串
```

类型一旦推导完成就固定下来。普通变量也必须提供初始化器：

```cpp
// auto value; // 错误：没有信息可供推导
```

### 5.1 `const auto a;` 为什么不合法？

```cpp
// const auto a; // 错误
```

`auto` 只是占位符，编译器必须查看初始化器才能知道应当替换成什么类型。这里没有初始化器，因此无法判断 `a` 是 `const int`、`const std::string` 还是其他类型。

提供初始化器后才合法：

```cpp
const auto a = 7;                  // const int
const auto b = std::string("hi");  // const std::string
```

可以理解为分两步：

```text
根据初始化器推导 auto
→ 再应用声明中明确写出的 const
```

`const auto` 中的 `const` 是顶层 `const`，表示推导得到的对象本身不可修改：

```cpp
const auto a = 7;
// a = 8; // 错误
```

如果 `auto` 推导成指针，`const` 默认修饰指针变量本身：

```cpp
int value = 3;
const auto pointer = &value; // int* const

*pointer = 4;      // 正确：所指 int 可修改
// pointer = nullptr; // 错误：指针本身是 const
```

这与指向常量的指针不同：

```cpp
const auto* pointer = &value; // const int*
```

这里 `pointer` 可以改指别处，但不能通过它修改 `value`。

### 5.2 `auto` 能否推导出带 `const` 的类型？

可以得到带 `const` 的最终类型，但必须区分按值推导、显式添加 `const` 和保留底层 `const`。

**普通按值 `auto` 不保留初始化器的顶层 `const`：**

```cpp
const int original = 7;
auto a = original; // int
```

这里 `auto` 推导为 `int`，`a` 是可修改的独立副本。

**在声明中明确写 `const`，最终对象是常量：**

```cpp
const auto b = original; // const int
auto const c = original; // const int，与上一行相同
```

这里可以理解为 `auto` 先按值推导为 `int`，再由声明中的 `const` 得到 `const int`。

**使用引用时会保留被引用对象的 `const`：**

```cpp
auto& reference = original; // const int&
```

如果去掉 `const`，非常量引用就可能修改原本的常量对象，因此推导结果必须保持只读。

**指针所指类型中的底层 `const` 会保留：**

```cpp
auto pointer = &original;  // const int*
auto* pointer2 = &original; // const int*
```

这两个指针变量自身可以改变指向，但不能通过它们修改 `original`。

**`auto&&` 遇到 `const` 左值时，最终也成为常量左值引用：**

```cpp
auto&& forwarding = original; // const int&
```

因为 `original` 是 `const int` 左值，类型推导和引用折叠得到 `const int&`，而不是可修改的 `int&&`。

结论：

```text
auto a = const对象       → 去掉顶层 const，按值复制
const auto a = 表达式    → 明确创建 const 对象
auto& a = const对象      → const T&
auto a = 指向const的指针 → const T*
auto&& a = const左值     → const T&
```

### 5.3 `auto&` 是引用吗？

是。变量声明中的 `auto&` 表示先从初始化器推导类型，再声明一个左值引用。最终类型一定是某种 `T&` 或 `const T&`：

```cpp
int value = 1;
auto& reference = value; // int&
```

`reference` 是 `value` 的别名，不是副本：

```cpp
reference = 10; // 实际修改 value
```

与普通按值 `auto` 对比：

```cpp
int value = 1;

auto copy = value;       // int，新对象
auto& reference = value; // int&，原对象的别名

copy = 2;      // value 仍为 1
reference = 3; // value 变成 3
```

如果初始化器是常量对象，推导结果会保留 `const`：

```cpp
const int fixed = 7;
auto& reference = fixed; // const int&

// reference = 8; // 错误
```

普通 `auto&` 不能绑定临时值：

```cpp
// auto& reference = 3; // 错误：非常量左值引用不能绑定纯右值
```

需要只读地绑定临时值时使用：

```cpp
const auto& reference = 3; // const int&
```

引用必须初始化，并且初始化后不能重新绑定：

```cpp
int first = 1;
int second = 2;
auto& reference = first;

reference = second;
```

最后一行不是让 `reference` 改为引用 `second`，而是把 `second` 的值赋给 `first`。

**简记：**

```text
auto  → 按值副本
auto& → 左值引用
const auto& → 只读左值引用，可绑定临时值
auto&& → 根据初始化器进行引用推导和折叠
```

### 6. 常见形式

| 写法 | 主要含义 |
|---|---|
| `auto x = expr;` | 按值创建新对象，通常去掉引用和顶层 `const` |
| `auto& x = expr;` | 推导并绑定左值引用 |
| `const auto& x = expr;` | 绑定只读引用，也能绑定临时值 |
| `auto* x = expr;` | 明确推导指针类型 |
| `auto&& x = expr;` | 根据初始化器值类别发生引用推导和折叠 |

### 7. C++11 版本边界

C++11 支持变量 `auto` 和尾置返回类型：

```cpp
auto add(int a, int b) -> int
{
    return a + b;
}
```

仅根据函数体自动推导普通函数返回类型是 C++14 功能，不应写成 C++11：

```cpp
// auto add(int a, int b) { return a + b; } // 不是严格 C++11
```

**一句话记忆：** `auto` 可以推导几乎所有可从初始化器确定的类型；普通 `auto` 得到按值副本并去掉引用和顶层 `const`，需要引用时必须明确写 `auto&`、`const auto&` 或相应引用形式。

## W017：`using Count = unsigned long;` 是什么语法？

**问题：** C++11 中是否存在 `using Count = unsigned long;` 这种语法？它有什么作用？

**核心答案：** 有。这是 C++11 的类型别名声明，表示 `Count` 是已有类型 `unsigned long` 的另一个名字。它与 `typedef unsigned long Count;` 基本等价，不创建变量，也不创建独立的新类型。

### 1. 基本语法

```cpp
using Count = unsigned long;

Count total = 10;
```

编译器把 `Count` 当作 `unsigned long` 使用：

```cpp
unsigned long total = 10;
```

别名声明的一般形式是：

```cpp
using 别名 = 原类型;
```

### 2. 与 `typedef` 对比

下面两句表达相同类型别名：

```cpp
typedef unsigned long Count;
using Count = unsigned long;
```

`using` 的书写顺序通常更直观，可以读成“`Count` 等于 `unsigned long`”。

复杂类型的差别更明显。定义函数指针别名：

```cpp
typedef void (*OldHandler)(int);
using Handler = void (*)(int);
```

两者含义相同，但 `using` 通常更容易从左到右阅读。

### 3. 类型别名不是新类型

```cpp
using Count = unsigned long;
```

`Count` 和 `unsigned long` 是同一种类型：

```cpp
void process(unsigned long);
// void process(Count); // 不是新重载，而是同一个函数的重复声明
```

两个不同别名也不能提供强类型隔离：

```cpp
using UserId = unsigned long;
using OrderId = unsigned long;

UserId user = 1;
OrderId order = user; // 合法，因为底层仍是同一种类型
```

如果需要防止不同业务量相互混用，应定义包装类、结构体或适当的 `enum class`，而不是只使用别名。

### 4. C++11 的别名模板

`using` 比 `typedef` 更重要的能力是可以直接定义别名模板：

```cpp
#include <vector>

template<class T>
using NumberList = std::vector<T>;

NumberList<int> values;
```

这里：

```cpp
NumberList<int>
```

等价于：

```cpp
std::vector<int>
```

传统 `typedef` 不能直接写出这种别名模板形式，通常需要额外的类模板包装。

### 5. `using` 关键字还有其他用途

下面使用同一个关键字，但不是类型别名：

```cpp
using std::cout;       // using 声明：把特定名字引入当前作用域
using namespace std;   // using 指令：引入命名空间中的名字
```

在派生类中还可写：

```cpp
using Base::function;
```

用于把基类的重载成员引入派生类作用域。判断含义时必须看完整语法。

### 6. `unsigned long` 的大小不固定

类型别名不会改变原类型的范围和大小：

```cpp
using Count = unsigned long;
```

`Count` 的大小就是当前实现中 `unsigned long` 的大小，C++11 不保证它固定为 32 位或 64 位。

**一句话记忆：** `using 新名字 = 原类型;` 是 C++11 类型别名语法；它提高可读性并支持别名模板，但只是改名字，不会创造新的独立类型。

## W018：`const` 的左右位置怎样理解？

**问题：** `const` 有所谓左右结合性吗？`const int*`、`int* const` 等声明怎样阅读？

**核心答案：** `const` 不是二元运算符，没有运算符意义上的左结合或右结合。它是类型限定符，关键是判断它限定的是整数、指针还是其他类型层级。`const int` 与 `int const` 完全相同；遇到指针时，从变量名向外阅读最可靠。

### 1. `const int` 与 `int const` 相同

```cpp
const int a = 1;
int const b = 2;
```

`a`、`b` 都是 `const int` 对象。这里 `const` 写在基础类型左边或右边，含义没有区别。

一种常用的辅助口诀是：

> `const` 优先看左边；左边没有可限定的类型成分时再看右边。

它只是阅读辅助，不是运算符结合性规则。

### 2. 指向常量的指针

```cpp
const int* pointer;
int const* pointer2;
```

两者类型相同，都是：

```text
指向 const int 的指针
```

`const` 限定所指的 `int`，不是指针变量：

```cpp
int first = 1;
int second = 2;

const int* pointer = &first;
pointer = &second; // 正确：指针可以改变指向
// *pointer = 3;   // 错误：不能通过 pointer 修改所指整数
```

### 3. 常量指针

```cpp
int* const pointer = &first;
```

从变量名 `pointer` 向外读：

```text
pointer 是 const 的
pointer 是一个指针
它指向 int
```

所以它是“指向 `int` 的常量指针”：

```cpp
*pointer = 3;       // 正确：所指 int 可以修改
// pointer = &second; // 错误：指针本身不能改变指向
```

### 4. 指针和所指对象都为常量

```cpp
const int* const pointer = &first;
// 等价于：
int const* const pointer2 = &first;
```

这是：

```text
指向 const int 的 const 指针
```

因此两种修改都不允许：

```cpp
// *pointer = 3;       // 错误
// pointer = &second;  // 错误
```

### 5. 四种写法对比

| 声明 | 指针能否改指向 | 能否通过指针修改对象 |
|---|---:|---:|
| `int* p` | 可以 | 可以 |
| `const int* p` | 可以 | 不可以 |
| `int* const p` | 不可以 | 可以 |
| `const int* const p` | 不可以 | 不可以 |

简化记忆：

```text
const 在 * 左边 → 所指对象只读
const 在 * 右边 → 指针本身只读
```

### 6. 顶层与底层 `const`

```cpp
const int* pointer; // 底层 const：所指 int 只读
int* const pointer2 = nullptr; // 顶层 const：pointer2 本身只读
```

- 顶层 `const` 限定当前对象本身。
- 底层 `const` 位于指针、引用等复合类型内部，限定它所访问的对象。

这解释了普通按值 `auto` 为什么会去掉顶层 `const`，却保留指针所指类型中的底层 `const`。

### 7. 类型别名的常见陷阱

```cpp
using IntPointer = int*;

int value = 1;
const IntPointer pointer = &value;
```

`IntPointer` 已经是完整的 `int*` 类型，因此：

```cpp
const IntPointer
```

等价于：

```cpp
int* const
```

而不是 `const int*`。`const` 限定整个别名类型，也就是指针本身。

### 8. 引用中的 `const`

```cpp
const int& reference = value;
int const& reference2 = value;
```

两者都是“到 `const int` 的引用”。引用建立后本来就不能重新绑定，所以不存在通过 `int& const` 给引用本身再加顶层 `const` 的普通写法。

### 9. 成员函数后的 `const`

```cpp
class Counter {
public:
    int get() const;
};
```

这里的 `const` 限定成员函数对当前对象的访问，表示不能通过该成员函数修改对象的普通非 `mutable` 成员。它不是在限定返回类型 `int`。

**一句话记忆：** `const int` 与 `int const` 相同；遇到 `*` 时，左侧 `const` 通常限制所指对象，右侧 `const` 限制指针本身；复杂声明从变量名向外读。

## W019：C++11 的 `constexpr` 详解

**问题：** `constexpr` 是什么？它与 `const`、编译期计算、函数和构造函数分别有什么关系？

**核心答案：** `constexpr` 表示“满足常量表达式规则”。它用于对象时，要求初始化器能够形成常量表达式，并使对象本身成为 `const`；用于函数或构造函数时，表示该函数在满足条件的调用中可以参与常量表达式计算。`constexpr` 函数并不是每次调用都必须在编译期执行。

### 1. 为什么需要 `constexpr`

C++ 的某些位置要求值在翻译程序时就能确定，例如：

```cpp
constexpr int length = 8;

int values[length];               // 内置数组长度
static_assert(length > 0, "");    // 编译期断言

enum { buffer_size = length };    // 枚举常量

template<int N>
struct Buffer {
    int data[N];
};

Buffer<length> buffer;            // 非类型模板实参
```

`case` 标签也要求整数常量表达式：

```cpp
switch (length) {
case 8:
    break;
}
```

`constexpr` 让程序员明确表达“这个值必须满足常量表达式要求”，并让编译器在不满足时直接诊断。

### 2. `constexpr` 变量

```cpp
constexpr int count = 6;
```

这同时表示：

1. `count` 必须初始化。
2. 初始化器必须满足常量表达式规则。
3. `count` 是 `const int`，之后不能修改。
4. `count` 的类型必须是字面类型。

所以下面不合法：

```cpp
// constexpr int missing; // 错误：没有初始化器
// count = 7;              // 错误：constexpr 对象是 const
```

“字面类型”是能够参与常量表达式构造的一类类型。整数、浮点数、指针等标量类型属于字面类型；符合额外条件并具有合适 `constexpr` 构造函数的类也可以是字面类型。

### 3. `const` 与 `constexpr` 的区别

```cpp
int read_value();

const int a = read_value();        // 可以：a 只读，但值可在运行期取得
// constexpr int b = read_value(); // 错误：普通函数调用不是常量表达式

const int c = 5;                   // c 也可能用于整数常量表达式
constexpr int d = 5;               // 明确要求初始化满足常量表达式规则
```

两者的重点不同：

| 写法 | 重点 |
|---|---|
| `const T object` | 通过该对象不能修改值 |
| `constexpr T object` | 初始化必须是常量表达式，而且对象隐含为 `const` |

因此：

```cpp
constexpr const int value = 3;
```

合法，但第二个 `const` 是重复表达；通常写成：

```cpp
constexpr int value = 3;
```

也不能反过来说“`const` 一定不是编译期常量”。像 `const int c = 5;` 这样的对象也可能满足特定常量表达式规则；只是 `const` 本身没有普遍承诺初始化器一定是常量表达式。

### 4. `constexpr` 函数：可以编译期计算，不是只能编译期调用

```cpp
constexpr int square(int number)
{
    return number * number;
}

constexpr int first = square(4); // 常量表达式，first 为 16

int runtime_input();
int n = runtime_input();
int second = square(n);          // 合法：这里可以作为普通运行期函数调用
```

`square(4)` 的实参是常量表达式，而且函数体符合规则，所以它可以形成常量表达式。`square(n)` 的 `n` 在运行期取得，因此这次调用不是常量表达式，但调用本身仍然合法。

最准确的记法是：

```text
constexpr 函数 = 有机会用于编译期常量表达式的函数
constexpr 变量的初始化 = 必须成功形成常量表达式
```

即使没有写 `constexpr`，优化器也可能把普通函数调用折叠为常数；那是优化行为，不是语言接口作出的常量表达式保证。

### 5. 严格 C++11 对 `constexpr` 函数体的限制

C++11 中，普通 `constexpr` 函数必须具有字面返回类型和字面参数类型，不能是虚函数；函数体基本上只能包含恰好一个 `return`，以及少量不产生运行步骤的声明。

条件逻辑通常要写进条件运算符：

```cpp
constexpr int absolute(int number)
{
    return number < 0 ? -number : number;
}
```

递归也可以表达重复计算：

```cpp
constexpr unsigned factorial(unsigned number)
{
    return number < 2 ? 1 : number * factorial(number - 1);
}

static_assert(factorial(5) == 120, "");
```

下面这种多语句、局部变量和循环形式不符合 C++11 的 `constexpr` 函数体规则：

```cpp
// 不属于合法的 C++11 constexpr 函数
/*
constexpr int sum_to(int number)
{
    int sum = 0;
    for (int i = 1; i <= number; ++i) {
        sum += i;
    }
    return sum;
}
*/
```

C++14 放宽了 `constexpr` 函数体规则，所以网上能编译的循环写法不一定属于 C++11。即便采用递归，编译器对常量求值的递归深度和资源仍有实现限制。

### 6. 并不是写了 `constexpr` 就一定能用于每次常量求值

```cpp
constexpr int divide(int left, int right)
{
    return left / right;
}

constexpr int good = divide(8, 2);
// constexpr int bad = divide(8, 0); // 错误：该次求值会除以零
```

函数声明符合 `constexpr` 形式，只代表合适的实参可以使调用成为常量表达式。具体调用仍要检查整条求值路径是否违反常量表达式规则。

在 C++11 常量求值中，常见的禁止项包括：

- 调用不符合要求的非 `constexpr` 函数。
- 执行未定义行为，例如除以零或有符号整数溢出。
- 使用 `new`、`delete`。
- 执行自增、自减或赋值等修改操作。
- 读取不允许在常量表达式中读取的运行期对象。
- 走到 `throw` 表达式。

### 7. `constexpr` 构造函数

`constexpr` 构造函数使类对象有机会在常量表达式中被构造：

```cpp
struct Point {
    int x;
    int y;

    constexpr Point(int x_value, int y_value)
        : x(x_value), y(y_value)
    {
    }

    constexpr int sum() const
    {
        return x + y;
    }
};

constexpr Point point(2, 3);
static_assert(point.sum() == 5, "");
```

严格 C++11 中，`constexpr` 构造函数的函数体通常为空；成员和基类子对象必须通过成员初始化列表、默认成员初始化器等允许的方式全部初始化。类不能有虚基类，相关成员和基类的构造也必须满足常量表达式要求。

拥有 `constexpr` 构造函数不表示该类的每个对象都是常量：

```cpp
Point runtime_point(1, 2); // 普通、可修改的运行期对象
runtime_point.x = 10;      // 合法
```

使 `point` 成为只读对象的是对象声明中的 `constexpr`，不是构造函数单独把整个类型变成了只读类型。

### 8. C++11 中 `constexpr` 成员函数隐含 `const`

C++11 规定，非静态且不是构造函数的 `constexpr` 成员函数隐含为 `const` 成员函数。因此：

```cpp
struct Number {
    int value;

    constexpr int get() const
    {
        return value;
    }
};
```

末尾显式写出的 `const` 在 C++11 中虽然语义上重复，但能把“不会修改当前对象”的接口意图写清楚，也更利于阅读和跨版本理解。

这个“隐含 `const`”是 C++11 的特殊规则；C++14 改变了相关规则，阅读不同标准版本的资料时要注意边界。

### 9. `constexpr` 指针限定的是指针本身

```cpp
int global_value = 0;
constexpr int* pointer = &global_value;
```

`pointer` 的实际类型是：

```cpp
int* const
```

也就是“指向 `int` 的常量指针”，不是“指向 `const int` 的指针”：

```cpp
*pointer = 5; // 合法：所指的 int 不是 const
// pointer = nullptr; // 错误：pointer 本身是 const
```

这里能使用 `&global_value`，是因为具有静态存储期对象的地址可以满足相应地址常量表达式规则。普通自动局部对象的地址不能用来初始化这种 C++11 `constexpr` 指针：

```cpp
void function()
{
    int local = 0;
    // constexpr int* bad = &local; // 错误
}
```

### 10. `static constexpr` 数据成员与 C++11 的类外定义

```cpp
struct Limits {
    static constexpr int maximum = 64;
};

int data[Limits::maximum]; // 作为常量值使用
```

在 C++11 中，如果该静态成员被 ODR-use，例如程序要取得它的地址或把它绑定到需要对象实体的引用，通常还要在一个 `.cpp` 文件中提供唯一类外定义：

```cpp
constexpr int Limits::maximum; // 不再写初始化器
```

C++17 的 `inline constexpr` 静态数据成员改变了这方面的常见写法，但那不属于 C++11。

### 11. `constexpr` 函数通常为什么定义在头文件

`constexpr` 函数和 `constexpr` 构造函数隐含为 `inline`。要让调用处进行常量求值，编译器通常必须在该翻译单元中看到函数定义，而不只是声明，所以这类短函数常直接定义在头文件中：

```cpp
// math_util.h
constexpr int cube(int number)
{
    return number * number * number;
}
```

隐含的 `inline` 规则允许多个翻译单元通过同一个头文件看到相同定义，而不会因此形成普通非 `inline` 外部函数的重复定义问题。

同一个函数的所有声明都必须一致地带有 `constexpr`：

```cpp
constexpr int cube(int number);
// int cube(int number); // 错误：遗漏 constexpr
```

### 12. `constexpr` 不等于“没有运行期开销或存储”

`constexpr` 主要是语言语义约束，不是性能开关：

- 在必须使用常量表达式的位置，编译器必须验证表达式满足规则。
- 在普通运行期上下文中，`constexpr` 函数可以照常运行。
- 对象是否实际占用存储，要看它是否需要对象实体，例如是否取地址。
- 普通表达式也可能被优化器在编译时计算。
- `constexpr` 不保证程序一定比不用它更快。

### 13. 容易混入 C++11 的后续版本语法

| 特性 | 所属版本 |
|---|---|
| 基础 `constexpr` 变量、函数和构造函数 | C++11 |
| 放宽 `constexpr` 函数体，可写局部变量和循环 | C++14 |
| `if constexpr` | C++17 |
| `constexpr` Lambda | C++17 |
| `inline static constexpr` 数据成员 | C++17 |
| `consteval`、`constinit` | C++20 |

下面不是 C++11：

```cpp
// if constexpr (...) { } // C++17
// consteval int f();      // C++20
// constinit int value;    // C++20
```

### 14. 最小判断流程

看到 `constexpr` 时依次判断：

1. 它修饰的是对象、普通函数，还是构造函数？
2. 如果是对象：是否已初始化，类型是否为字面类型，初始化器是否是常量表达式？
3. 如果是函数：是否满足严格 C++11 的单一 `return` 等函数体限制？
4. 如果是一次函数调用：这次传入的实参和实际执行路径是否都满足常量表达式规则？
5. 当前位置是否强制要求常量表达式？
6. 示例是否偷偷使用了 C++14、C++17 或 C++20 才加入的规则？

**一句话记忆：** C++11 的 `constexpr` 对对象表示“这个初始化必须是常量表达式，而且对象只读”；对函数表示“满足条件的调用可以成为常量表达式”，而不是“每次调用都强制在编译期执行”。

## W020：位运算与基本数值类型极限

**问题：** C++11 的位运算怎样使用？`INT_MAX`、`FLT_MAX`、`DBL_MAX` 等宏分别表示什么？怎样查询各类型的最小值和最大值？

**核心答案：** 位运算直接处理整数的二进制位，基础运算符是 `&`、`|`、`^`、`~`、`<<`、`>>`。为了避免符号表示和移位规则带来的问题，位掩码通常使用无符号整数。整数极限宏来自 `<climits>`，浮点极限宏来自 `<cfloat>`；C++ 中更统一、类型安全的查询方式是 `<limits>` 中的 `std::numeric_limits<T>`。最容易混淆的是：对浮点类型，`FLT_MIN` 和 `DBL_MIN` 表示最小正正规数，不是最负数。

### 1. 六个位运算符

假设只观察最低三位：

```text
a = 6 = 110
b = 3 = 011
```

| 运算 | 名称 | 逐位规则 | 示例结果 |
|---|---|---|---:|
| `a & b` | 按位与 | 两位都为 `1` 才是 `1` | `010`，即 `2` |
| `a \| b` | 按位或 | 至少一位为 `1` 就是 `1` | `111`，即 `7` |
| `a ^ b` | 按位异或 | 两位不同才是 `1` | `101`，即 `5` |
| `~a` | 按位取反 | 每一位 `0/1` 互换 | 取决于完整类型位宽 |
| `a << n` | 左移 | 向左移动 `n` 位 | 受类型和范围规则限制 |
| `a >> n` | 右移 | 向右移动 `n` 位 | 有符号负数结果与实现有关 |

`~a` 会翻转类型的全部位，不能只按写出来的三位计算。若 `unsigned int` 有 32 个值位，`~6u` 翻转的是完整 32 位。

### 1.1 异或与同或

异或已经是 C++ 的内置运算符 `^`：

```text
0 ^ 0 = 0
0 ^ 1 = 1
1 ^ 0 = 1
1 ^ 1 = 0
```

即“两位不同为 `1`，相同为 `0`”。常见性质：

```cpp
x ^ 0u == x;
x ^ x == 0u;
x ^ y ^ y == x;
```

C++ 没有独立的同或运算符。同或是异或的取反：

```cpp
unsigned int xnor = ~(left ^ right);
```

同或的真值表：

```text
0 XNOR 0 = 1
0 XNOR 1 = 0
1 XNOR 0 = 0
1 XNOR 1 = 1
```

即“两位相同为 `1`，不同为 `0`”。`~` 会处理完整类型的全部位；若只关注低 `N` 位，必须再加宽度掩码：

```cpp
unsigned int low4_xnor =
    ~(left ^ right) & 0xFu; // 只保留低 4 位
```

对两个布尔条件，逻辑异或和同或可直接写成：

```cpp
bool logical_xor  = left_condition != right_condition;
bool logical_xnor = left_condition == right_condition;
```

不要把按位取反 `~` 当成逻辑非 `!`。

它们还有复合赋值形式：

```cpp
flags &= mask;
flags |= mask;
flags ^= mask;
flags <<= count;
flags >>= count;
```

### 2. 位运算不是逻辑运算

| 位运算 | 逻辑运算 |
|---|---|
| `&` | `&&` |
| `\|` | `\|\|` |
| `~` | `!` |

位运算处理整数的每一位；逻辑运算把操作数解释为真假，结果是 `bool`。`&&` 和 `||` 具有短路求值，普通内置位运算 `&` 和 `|` 没有短路性质。

### 3. 位掩码的四个基本操作

```cpp
#include <limits>

using U = unsigned int;

U flags = 0;
unsigned int index = 3;

if (index < std::numeric_limits<U>::digits) {
    U mask = U(1) << index;

    flags |= mask;                  // 置 1
    flags &= ~mask;                 // 清 0
    flags ^= mask;                  // 翻转
    bool is_set = (flags & mask) != 0; // 测试
}
```

记忆：

```text
置位：|
清位：& ~
翻转：^
测试：& 后与 0 比较
```

`std::numeric_limits<U>::digits` 对无符号整数表示值位数量。先检查 `index`，避免移位数量越界。

### 4. 为什么掩码常用无符号整数

```cpp
unsigned int mask = 1u << index;
```

后缀 `u` 使字面量 `1u` 的类型为 `unsigned int`。使用无符号类型的原因包括：

- 无符号整数按模算术定义，位模式和数值关系更直接。
- 无符号右移按补零方式处理。
- 避免负有符号数的表示方式和右移规则差异。
- 避免有符号左移超出可表示范围时的未定义行为。

C++11 不要求有符号整数一定采用二进制补码，还允许其他符合要求的表示，因此底层位操作不要依赖“所有机器都和当前机器一样”。

### 5. C++11 的移位边界

对于：

```cpp
left << count
left >> count
```

必须记住：

1. 两个操作数会进行整数提升。
2. 结果类型是提升后的左操作数类型。
3. `count < 0` 是未定义行为。
4. `count` 大于或等于提升后左操作数的位数，是未定义行为。
5. 无符号左移按相应模数处理。
6. 负有符号数左移是未定义行为。
7. 非负有符号数左移若数学结果不能由结果类型表示，是未定义行为。
8. 无符号数或非负有符号数右移，相当于除以 `2^count` 后取整数部分。
9. 负有符号数右移的结果在 C++11 中由实现定义。

因此：

```cpp
unsigned int good = 1u << 3; // 典型结果为 8

// 若 unsigned int 有 N 个值位：
// 1u << N;                   // 错误：移位数量越界，未定义行为

int negative = -1;
// negative << 1;             // 未定义行为
// negative >> 1;             // C++11：结果由实现定义
```

最稳妥的基础规则是：位运算使用明确的无符号类型，并在移位前检查数量。

字面量本身的类型必须足够宽：

```cpp
unsigned long long wide_mask = 1ULL << 40; // 正确：先用宽类型移位

// 若 unsigned int 只有 32 位，下面在赋值前就已经出错：
// unsigned long long bad_mask = 1u << 40;
```

后续赋给更宽类型不能挽救已经在较窄类型中发生的非法移位。`1u` 只是 `unsigned int`，不表示“任意宽的无符号数”。

### 6. 整数提升会改变结果类型

`bool`、`char`、`signed char`、`unsigned char`、`short` 等小整数类型参与许多位运算时，会先提升为 `int`；若 `int` 不能表示原类型全部值，才提升为 `unsigned int`。

```cpp
unsigned char byte = 0x0F;
auto result = ~byte;
```

`result` 通常是 `int`，不是 `unsigned char`。因为 `byte` 先被提升，再对完整的 `int` 位宽取反。若只想保留一个字节，应在确认目标语义后显式转换：

```cpp
unsigned char inverted =
    static_cast<unsigned char>(~byte);
```

同理，两个不同整数类型执行 `&`、`|`、`^` 时还会进行通常算术转换；混合有符号与无符号类型可能把有符号值转成无符号值。

### 7. 优先级陷阱

下面的写法不是通常想表达的意思：

```cpp
if (flags & mask == 0) {
}
```

`==` 的优先级高于按位与 `&`，所以它按下面方式分组：

```cpp
flags & (mask == 0)
```

正确写法：

```cpp
if ((flags & mask) == 0) {
}
```

涉及位运算和比较时主动加括号，不要靠记忆猜优先级。

C++11 还没有标准二进制整数字面量：

```cpp
// unsigned int mask = 0b1010; // C++14 才成为标准写法
unsigned int mask = 0xAu;      // C++11 可用
```

### 8. `enum class` 不能直接进行内置位运算

```cpp
enum class Permission : unsigned int {
    read  = 1u << 0,
    write = 1u << 1
};

// Permission::read | Permission::write; // 没有内置的匹配运算
```

`enum class` 不会隐式转换为整数。若要把它设计成标志集合，应为该枚举明确重载所需位运算符，或者在边界处显式转换到底层无符号类型；不要无意中把强类型枚举退化成任意整数。

流表达式中的：

```cpp
std::cout << value;
std::cin >> value;
```

使用的是重载后的 `operator<<` 和 `operator>>`，语义是流插入和流提取，不是在移动整数位。

### 9. 整数极限宏：`<climits>`

```cpp
#include <climits>
```

| 类型 | 最小值宏 | 最大值宏 |
|---|---|---|
| `signed char` | `SCHAR_MIN` | `SCHAR_MAX` |
| `unsigned char` | 固定为 `0` | `UCHAR_MAX` |
| 普通 `char` | `CHAR_MIN` | `CHAR_MAX` |
| `short` | `SHRT_MIN` | `SHRT_MAX` |
| `unsigned short` | 固定为 `0` | `USHRT_MAX` |
| `int` | `INT_MIN` | `INT_MAX` |
| `unsigned int` | 固定为 `0` | `UINT_MAX` |
| `long` | `LONG_MIN` | `LONG_MAX` |
| `unsigned long` | 固定为 `0` | `ULONG_MAX` |
| `long long` | `LLONG_MIN` | `LLONG_MAX` |
| `unsigned long long` | 固定为 `0` | `ULLONG_MAX` |

其他重要宏：

```cpp
CHAR_BIT // 一个 C++ 字节中有多少位；标准不强制必须等于 8
```

普通 `char` 的有符号性由实现决定，因此 `CHAR_MIN` 可能等于 `0`，也可能等于 `SCHAR_MIN`。

### 10. 常见整数值不是 ISO C++11 的固定承诺

在常见的 8 位字节、二进制补码平台上：

| 类型假设 | 常见最小值 | 常见最大值 |
|---|---:|---:|
| 8 位 `signed char` | `-128` | `127` |
| 8 位 `unsigned char` | `0` | `255` |
| 16 位 `short` | `-32768` | `32767` |
| 16 位 `unsigned short` | `0` | `65535` |
| 32 位 `int` | `-2147483648` | `2147483647` |
| 32 位 `unsigned int` | `0` | `4294967295` |
| 64 位 `long long` | `-9223372036854775808` | `9223372036854775807` |
| 64 位 `unsigned long long` | `0` | `18446744073709551615` |

但 ISO C++11 不固定这些类型的精确字节数，也不固定有符号整数必须是二进制补码。尤其是：

- 64 位 Windows 通常仍然使用 32 位 `long`。
- 许多 64 位 Linux 系统使用 64 位 `long`。
- `int` 不保证一定为 4 字节。

需要当前实现的真实范围时读取宏或 `std::numeric_limits`，不要把常见值硬编码成标准事实。

### 11. 浮点极限宏：`<cfloat>`

```cpp
#include <cfloat>
```

| 类型 | 最小正正规数 | 最大有限值 | `1` 附近间距 |
|---|---|---|---|
| `float` | `FLT_MIN` | `FLT_MAX` | `FLT_EPSILON` |
| `double` | `DBL_MIN` | `DBL_MAX` | `DBL_EPSILON` |
| `long double` | `LDBL_MIN` | `LDBL_MAX` | `LDBL_EPSILON` |

宏名区分大小写，正确名称是：

```cpp
FLT_MAX
DBL_MAX
```

不是 `flt_max` 或 `dbl_max`。

最重要的区别：

```text
INT_MIN = int 的最小值，也就是最负的 int
FLT_MIN = float 的最小正正规值，不是最负的 float
DBL_MIN = double 的最小正正规值，不是最负的 double
```

`FLT_MAX` 和 `DBL_MAX` 表示最大有限值，不包含正无穷。是否支持无穷和 NaN，要查询实现属性。

### 12. 常见 IEEE 754 浮点值

下表是常见实现的参考值，不是 ISO C++11 对所有平台的固定要求：

| 宏 | 常见近似值 | 含义 |
|---|---:|---|
| `FLT_MIN` | `1.17549435e-38F` | 最小正正规 `float` |
| `FLT_MAX` | `3.40282347e+38F` | 最大有限 `float` |
| `FLT_EPSILON` | `1.19209290e-7F` | `1.0F` 与下一个可表示值之差 |
| `DBL_MIN` | `2.2250738585072014e-308` | 最小正正规 `double` |
| `DBL_MAX` | `1.7976931348623157e+308` | 最大有限 `double` |
| `DBL_EPSILON` | `2.2204460492503131e-16` | `1.0` 与下一个可表示值之差 |

在常见对称 IEEE 754 表示中，最负有限 `float` 约为 `-FLT_MAX`，最负有限 `double` 约为 `-DBL_MAX`。通用 C++11 代码应使用 `lowest()` 查询，而不是假定表示必然对称。

若实现支持常见的 IEEE 754 次正规数，则还常见：

```text
float  denorm_min() ≈ 1.40129846e-45
double denorm_min() ≈ 4.9406564584124654e-324
```

`FLT_TRUE_MIN`、`DBL_TRUE_MIN` 等宏不属于 ISO C++11。C++11 应使用 `std::numeric_limits<T>::denorm_min()` 查询相应值。

### 13. 推荐的 C++ 查询方式：`std::numeric_limits`

```cpp
#include <limits>

int int_minimum = std::numeric_limits<int>::min();
int int_maximum = std::numeric_limits<int>::max();

float float_smallest_normal =
    std::numeric_limits<float>::min();
float float_most_negative =
    std::numeric_limits<float>::lowest();
float float_largest =
    std::numeric_limits<float>::max();
```

三者含义：

| 函数 | 整数 | 浮点数 |
|---|---|---|
| `min()` | 类型最小值；有符号整数为最负值，无符号整数为 `0` | 最小正正规值 |
| `lowest()` | 类型最小值；有符号整数为最负值，无符号整数为 `0` | 最负有限值 |
| `max()` | 最大值 | 最大有限值 |

为了让泛型代码对整数和浮点数都取得“最负值”，应使用：

```cpp
std::numeric_limits<T>::lowest()
```

而不是统一使用 `min()`。

其他常用属性：

```cpp
std::numeric_limits<T>::digits          // 整数值位数或浮点有效二进制位数
std::numeric_limits<T>::digits10        // 可无损表示的十进制位数
std::numeric_limits<T>::max_digits10    // 浮点值往返文本所需位数
std::numeric_limits<T>::is_signed       // 是否有符号
std::numeric_limits<T>::is_integer      // 是否为整数
std::numeric_limits<T>::epsilon()       // 浮点 1 附近的间距
std::numeric_limits<T>::denorm_min()    // 支持时的最小正次正规值
std::numeric_limits<T>::has_infinity    // 是否支持无穷
std::numeric_limits<T>::infinity()      // 支持时取得正无穷
std::numeric_limits<T>::has_quiet_NaN   // 是否支持 quiet NaN
std::numeric_limits<T>::quiet_NaN()     // 支持时取得 quiet NaN
```

`epsilon()` 不是最小正数，也不是通用的浮点比较误差；它只描述 `1` 附近的表示间距。

### 14. 其他整数类型怎样查询

`bool`、字符类型和库中使用的整数类型也可以交给 `numeric_limits`：

```cpp
std::numeric_limits<bool>::min();       // false
std::numeric_limits<bool>::max();       // true

std::numeric_limits<wchar_t>::lowest();
std::numeric_limits<char16_t>::max();
std::numeric_limits<char32_t>::max();
std::numeric_limits<std::size_t>::max();
std::numeric_limits<std::ptrdiff_t>::lowest();
```

查询 `std::size_t` 和 `std::ptrdiff_t` 前应包含 `<cstddef>`。

若算法需要恰好 8、16、32 或 64 位整数，可检查 `<cstdint>` 中的 `std::int32_t`、`std::uint32_t` 等精确宽度类型；只有实现确实提供相应精确宽度整数时，这些类型和配套宏才存在。不要把普通 `int` 直接假定为 `std::int32_t`。

### 15. 输出当前平台真实范围

```cpp
#include <cfloat>
#include <climits>
#include <iomanip>
#include <iostream>
#include <limits>

int main()
{
    std::cout << "INT_MIN = " << INT_MIN << '\n';
    std::cout << "INT_MAX = " << INT_MAX << '\n';
    std::cout << "UINT_MAX = " << UINT_MAX << '\n';

    std::cout << std::setprecision(
        std::numeric_limits<double>::max_digits10);

    std::cout << "FLT_MIN = " << FLT_MIN << '\n';
    std::cout << "FLT_MAX = " << FLT_MAX << '\n';
    std::cout << "float lowest = "
              << std::numeric_limits<float>::lowest() << '\n';

    std::cout << "DBL_MIN = " << DBL_MIN << '\n';
    std::cout << "DBL_MAX = " << DBL_MAX << '\n';
    std::cout << "double lowest = "
              << std::numeric_limits<double>::lowest() << '\n';
}
```

### 16. 最终记忆表

```text
整数：
MIN = 最负值
MAX = 最大值
无符号最小值永远是 0

浮点：
MIN = 最小正正规值
lowest() = 最负有限值
MAX = 最大有限值
epsilon() = 1 附近的间距

位运算：
置位 |
清位 & ~
翻转 ^
测试 &
移位优先用无符号，并检查位数
```

**一句话记忆：** 整数的 `MIN` 是最负值，浮点的 `MIN` 却是最小正正规值；位掩码优先使用无符号类型，并始终检查整数提升、移位数量和运算符优先级。

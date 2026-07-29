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

## W011：构造函数重载、初始化形式和子对象初始化顺序

**问题：** 构造函数为什么可以重载？默认初始化、值初始化、直接初始化、拷贝初始化和列表初始化分别是什么？基类、成员和构造函数体为什么必须按照固定顺序初始化？

**核心答案：** 构造函数可以通过不同参数列表为同一类型提供不同的合法建造方式，编译器使用重载决议选择构造函数。各种初始化名称也不是完全互斥的平行分类：直接初始化和拷贝初始化描述初始化语境，列表初始化表示使用 `{}`，列表初始化又分直接列表初始化和拷贝列表初始化。一个完整类对象的子对象始终按照“虚基类、直接基类、成员声明顺序、构造函数体”初始化，与成员初始化列表的书写顺序无关。

| 写法 | 分类 |
|---|---|
| `T a;` | 默认初始化 |
| `T a{};` | 直接列表初始化；空列表会按相应规则产生值初始化效果 |
| `T()` | 值初始化一个临时结果 |
| `T a(x);` | 直接初始化，非列表初始化 |
| `T a = x;` | 拷贝初始化，非列表初始化 |
| `T a{x};` | 直接列表初始化 |
| `T a = {x};` | 拷贝列表初始化 |
| `Point p{1, 2};` | 直接列表初始化；若 `Point` 是聚合，同时也是聚合初始化 |
| `Point p = {1, 2};` | 拷贝列表初始化；若 `Point` 是聚合，同时也是聚合初始化 |

### 1. 构造函数为什么可以重载

构造函数与类同名，没有返回类型，但可以拥有不同的参数列表：

```cpp
class Point
{
public:
    Point()
        : x(0), y(0)
    {
    }

    explicit Point(int value)
        : x(value), y(value)
    {
    }

    Point(int x, int y)
        : x(x), y(y)
    {
    }

private:
    int x;
    int y;
};
```

使用时由实参参与重载决议：

```cpp
Point origin;       // Point()
Point both(5);      // Point(int)
Point position(2, 3); // Point(int, int)
```

重载的用途是为同一类型提供多种建立合法状态的方法。不同构造函数最终都应该保证对象满足同一组类不变量。

不能只靠返回类型区分重载，因为构造函数没有返回类型；两个构造函数的参数列表也不能完全相同。

### 2. 默认初始化

典型语法：

```cpp
T object;
```

对于类类型，会选择默认构造函数：

```cpp
Point point; // 调用 Point()
```

对于自动存储期的基础类型，默认初始化通常不会提供确定值：

```cpp
int number; // 值不确定，赋值前不能读取
```

“默认初始化”是语言中的初始化形式，不等于“对象一定得到默认值 0”，也不等于“构造函数一定由编译器生成”。

### 3. 值初始化

典型语法包括：

```cpp
int first = int();
int second{};
```

这里两个整数都得到 `0`。`second{}` 的外层语法是直接列表初始化，空列表再按照相应规则使标量得到值初始化效果。

类类型的值初始化会结合其构造函数情况处理：

```cpp
Point point{};
```

不要把“值初始化”简单理解为“任何类型都逐字节清零”。类对象最终状态由值初始化规则、默认构造函数和成员初始化共同决定。

### 4. 直接初始化

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

### 5. 拷贝初始化

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

### 6. 列表初始化

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

### 7. 聚合初始化

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

### 8. 与赋值的区别

```cpp
Student a;
Student b = a; // 初始化：b 正在开始生命周期
b = a;         // 赋值：b 已经存在
```

判断标准不是有没有 `=`，而是目标对象是否正在建立。

### 9. 一个完整对象的固定初始化顺序

对于最派生类对象，顺序固定为：

```text
1. 虚基类
2. 直接基类
3. 非静态数据成员，严格按照类中声明顺序
4. 构造函数体
```

例如：

```cpp
class Example
{
public:
    Example()
        : second(first + 1), first(10)
    {
    }

private:
    int first;
    int second;
};
```

虽然成员初始化列表先写 `second`，实际仍然是：

```text
first 先初始化为 10
second 再初始化为 first + 1，也就是 11
最后执行构造函数体
```

建议始终让成员初始化列表的书写顺序与成员声明顺序一致：

```cpp
Example()
    : first(10), second(first + 1)
{
}
```

这样更容易阅读，也能避免编译器的顺序警告。

直接基类同样按类定义中的基类列表顺序初始化：

```cpp
class Derived : public Base1, public Base2
{
public:
    Derived()
        : Base2(), Base1()
    {
    }
};
```

实际仍先构造 `Base1`，再构造 `Base2`。

虚继承可能让多个继承路径共享同一个虚基类子对象，因此虚基类由最派生类负责，并在普通直接基类之前初始化。

### 10. 为什么必须这样规定

#### 原因一：同一个类可以有多个构造函数

```cpp
class Object
{
public:
    Object()
        : first(1), second(2)
    {
    }

    explicit Object(int value)
        : second(value), first(value)
    {
    }

private:
    int first;
    int second;
};
```

如果初始化顺序跟随每个初始化列表的书写顺序，同一个类通过不同构造函数创建时，成员构造顺序就可能不同。固定按照声明顺序，可以让所有构造函数遵守同一个对象建立规则。

#### 原因二：析构顺序必须稳定

对象销毁时按照构造顺序的逆序进行：

```text
构造：Base1 → Base2 → first → second → 构造函数体
析构：析构函数体 → second → first → Base2 → Base1
```

固定构造顺序后，析构过程不需要记录“这次究竟使用哪个构造函数、初始化列表写了什么顺序”，也能始终正确逆序清理。

#### 原因三：成员之间的依赖必须可预测

```cpp
class Safe
{
private:
    int first;
    int second;

public:
    Safe()
        : first(10), second(first + 1)
    {
    }
};
```

`second` 可以安全依赖声明在它前面的 `first`。程序员只需查看类中的成员声明顺序，就能判断初始化依赖，而不必先寻找当前究竟调用了哪个构造函数。

#### 原因四：进入构造函数体前，子对象必须已经存在

```cpp
class Owner
{
public:
    Owner()
    {
        // 到这里时，基类和数据成员都已经完成初始化
    }

private:
    Resource resource;
};
```

构造函数体负责在完整子对象已经建立后执行额外逻辑；它不是初始化数据成员的第一阶段。在函数体中写：

```cpp
resource = Resource();
```

通常是给已经构造好的成员赋值，而不是首次初始化。

### 11. 声明顺序错误可能产生什么问题

```cpp
class Bad
{
public:
    Bad()
        : first(second), second(10)
    {
    }

private:
    int first;
    int second;
};
```

`first` 在声明中位于 `second` 前面，所以它一定先初始化。计算 `first(second)` 时，`second` 尚未初始化，读取它的值会产生未定义行为。即使初始化列表把 `second(10)` 写在前面，也不能改变真实顺序。

正确做法是调整声明顺序或依赖方向：

```cpp
class Good
{
public:
    Good()
        : first(10), second(first)
    {
    }

private:
    int first;
    int second;
};
```

**一句话记忆：** 构造函数重载提供不同建造入口；初始化形式决定如何选择初值和构造函数；真正的子对象顺序只看“虚基类、直接基类、成员声明顺序”，最后才进入构造函数体，并按相反顺序析构。

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
class Counter
{
public:
    int get() const
    {
        return value;
    }

private:
    int value = 0;
};
```

这里的 `const` 限定成员函数对当前对象的访问。它不是在限定返回类型 `int`。

#### 用途一：让常量对象和常量引用能够查询对象

```cpp
void print(const Counter& counter)
{
    int value = counter.get();
}
```

`counter` 是到常量对象的引用，只能通过它调用 `const` 成员函数。这样函数可以读取对象状态，同时向调用者承诺不会通过该引用修改对象的普通成员。

非 `const` 对象也可以调用 `const` 成员函数：

```cpp
Counter counter;
counter.get(); // 正确
```

因此只读查询函数通常应声明为 `const`，例如：

```cpp
size()
empty()
get_name()
find()
```

#### 用途二：让编译器检查是否意外修改当前对象

```cpp
class Counter
{
public:
    int get() const
    {
        // value = 10; // 错误：不能修改普通数据成员
        return value;
    }

private:
    int value = 0;
};
```

在 `const` 成员函数中，`this` 指向一个具有 `const` 限定的当前对象。因此不能：

- 修改当前对象的普通非 `mutable` 数据成员。
- 通过当前对象调用普通非 `const` 成员函数。
- 返回允许调用者修改普通成员的非 `const` 引用或指针。

这可以在编译阶段发现“查询函数意外修改对象”的错误。

#### 用途三：形成 `const` 与非 `const` 重载

成员函数末尾的 `const` 属于函数类型的一部分，因此可以重载：

```cpp
#include <cstddef>

class Buffer
{
public:
    char& at(std::size_t index)
    {
        return data[index];
    }

    const char& at(std::size_t index) const
    {
        return data[index];
    }

private:
    char data[10] = {};
};
```

使用规则：

```cpp
Buffer writable;
writable.at(0) = 'A'; // 调用非 const 版本，返回 char&

const Buffer readonly{};
char ch = readonly.at(0); // 调用 const 版本，返回 const char&
// readonly.at(0) = 'B';  // 错误：不能通过 const 引用修改元素
```

这种重载可以让同一个接口根据对象是否只读，返回不同权限的引用或指针。标准容器的 `operator[]`、`at()`、`begin()` 等接口大量采用这种设计。

#### 用途四：表达接口语义

```cpp
class Student
{
public:
    int score() const;
    void set_score(int score);
};
```

看到声明即可理解：

```text
score()      → 查询操作，不应改变对象的普通状态
set_score()  → 修改操作
```

这叫 const-correctness：把“只读”和“可修改”的权限写进类型系统，而不是只依靠注释。

#### 声明和定义必须同时写 `const`

```cpp
class Student
{
public:
    int score() const;
};

int Student::score() const
{
    return 0;
}
```

如果类外定义漏掉末尾的 `const`，它就不再是前面声明的同一个成员函数。

#### `const` 成员函数不代表完全没有副作用

它主要限制通过当前对象修改普通非 `mutable` 成员，但仍可能：

- 修改 `mutable` 成员。
- 修改静态数据成员。
- 修改指针所指向的外部对象。
- 执行输入输出、写日志或调用其他具有副作用的函数。

```cpp
class Cache
{
public:
    int query() const
    {
        ++query_count;
        return value;
    }

private:
    int value = 10;
    mutable int query_count = 0;
};
```

`mutable` 常用于缓存、统计或同步对象，但它不自动提供线程安全。

静态成员函数不能在末尾添加这种 `const`：

```cpp
// static int get() const; // 错误
```

因为静态成员函数没有 `this`，也就没有“当前对象是否为 const”可供限定。

**一句话记忆：** `const` 成员函数既允许只读对象调用，又提供编译期防误修改、const 重载和接口权限表达；它限制的是当前对象，不保证函数完全没有副作用。

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

## W021：浮点数如何进行位运算？

**问题：** `float`、`double` 能否直接使用位运算符？如果想读取或修改它们的二进制表示，C++11 应怎样做？

**核心答案：** C++11 的内置位运算只接受整数或非强作用域枚举，不能直接对 `float`、`double` 使用。若确实要检查对象表示，应使用 `std::memcpy` 把字节复制到同尺寸无符号整数中，再对整数进行位运算；不能用普通数值转换、违反严格别名规则的指针转换或不具可移植性的联合体类型双关。

### 1. 浮点数不能直接进行位运算

```cpp
float value = 5.5f;

// value & 1;   // 编译错误
// value << 1;  // 编译错误
// ~value;      // 编译错误
```

`&`、`|`、`^`、`~`、`<<`、`>>` 的内置版本不接受浮点类型。

### 2. 数值转换不等于复制位模式

```cpp
float value = 5.5f;
unsigned int number = static_cast<unsigned int>(value);
```

这里进行的是数值转换：

```text
5.5f → 5u
```

`number` 得到 `5`，不是 `5.5f` 的浮点对象表示。

### 3. C++11 中安全读取位模式：`std::memcpy`

```cpp
#include <cstdint>
#include <cstring>

std::uint32_t bits_of_float(float value)
{
    static_assert(sizeof(float) == sizeof(std::uint32_t),
                  "this implementation does not use a 32-bit float");

    std::uint32_t bits = 0;
    std::memcpy(&bits, &value, sizeof(bits));
    return bits;
}

float float_from_bits(std::uint32_t bits)
{
    static_assert(sizeof(float) == sizeof(std::uint32_t),
                  "this implementation does not use a 32-bit float");

    float value = 0.0f;
    std::memcpy(&value, &bits, sizeof(value));
    return value;
}
```

使用：

```cpp
float value = 5.5f;
std::uint32_t bits = bits_of_float(value);

bits ^= 0x80000000u; // 在常见 IEEE 754 binary32 中翻转符号位

float changed = float_from_bits(bits);
```

在常见 IEEE 754 32 位 `float` 实现中，`changed` 通常为 `-5.5f`。但 ISO C++11 不保证 `float` 一定是 IEEE 754 binary32，也不保证符号位一定处于该位置，所以这段掩码代码依赖表示格式。

### 4. 常见 IEEE 754 binary32 布局

常见的 32 位 `float` 布局为：

```text
31          30               23 22                       0
+--------------+---------------+--------------------------+
| 符号位 1 bit | 指数位 8 bits | 小数部分 23 bits         |
+--------------+---------------+--------------------------+
```

常见掩码：

```cpp
const std::uint32_t sign_mask     = 0x80000000u;
const std::uint32_t exponent_mask = 0x7F800000u;
const std::uint32_t fraction_mask = 0x007FFFFFu;

std::uint32_t sign = (bits & sign_mask) >> 31;
std::uint32_t exponent = (bits & exponent_mask) >> 23;
std::uint32_t fraction = bits & fraction_mask;
```

这些掩码只适用于已经确认采用相应 IEEE 754 binary32 对象表示的环境。

### 5. `double` 的常见做法

```cpp
#include <cstdint>
#include <cstring>

std::uint64_t bits_of_double(double value)
{
    static_assert(sizeof(double) == sizeof(std::uint64_t),
                  "this implementation does not use a 64-bit double");

    std::uint64_t bits = 0;
    std::memcpy(&bits, &value, sizeof(bits));
    return bits;
}
```

常见 IEEE 754 binary64 布局为：

```text
1 位符号 + 11 位指数 + 52 位小数部分
```

但它同样不是所有 ISO C++11 实现都必须采用的格式。

### 6. 不要使用这些写法

#### 6.1 违反严格别名规则的指针读取

```cpp
float value = 5.5f;

// 未定义行为或同时存在对齐风险：
// std::uint32_t bits =
//     *reinterpret_cast<std::uint32_t*>(&value);
```

`float` 对象不能随意通过不相容的 `std::uint32_t*` 解引用读取。

#### 6.2 联合体类型双关

```cpp
union FloatBits {
    float floating;
    std::uint32_t integer;
};
```

写入 `floating` 后读取非活动成员 `integer` 不是可移植的 ISO C++11 类型双关方案。部分编译器把它作为扩展支持，但标准 C++11 代码应使用 `std::memcpy`。

#### 6.3 普通强制转换

```cpp
unsigned int result = static_cast<unsigned int>(value);
```

它转换数值，不复制对象表示。

### 7. 修改任意位模式的风险

任意修改浮点位模式可能产生：

- 正数或负数。
- 正零或负零。
- 次正规数。
- 正无穷或负无穷。
- quiet NaN 或 signaling NaN。
- 当前实现不支持或会陷阱的表示。

从一个有效浮点对象复制出位模式，再原样复制回来，适合用于同一实现中的无损往返。把任意网络字节或整数位模式直接解释成浮点数，则必须先约定浮点格式、字节序和有效表示。

### 8. 只想处理数学属性时不要操作位模式

标准库通常更合适：

```cpp
#include <cmath>

int exponent = 0;

bool negative = std::signbit(value);          // 查询符号
float copied = std::copysign(3.0f, value);    // 复制符号
bool is_nan = std::isnan(value);              // 是否为 NaN
bool is_infinite = std::isinf(value);         // 是否为无穷
float fraction = std::frexp(value, &exponent);// 分解有效数与指数
float rebuilt = std::ldexp(fraction, exponent);// 按 2 的幂缩放
```

这些接口表达的是数学语义，不要求程序自行假定浮点对象的位布局。

### 9. C++20 与 C++11 的边界

C++20 提供：

```cpp
std::bit_cast
```

但它不属于 C++11。严格 C++11 中应使用 `std::memcpy`。

**一句话记忆：** 浮点数不能直接位运算；普通强制转换改变数值，`std::memcpy` 才能在 C++11 中安全复制对象表示，而具体符号位、指数位和小数位布局仍然取决于实现。

## W022：一次学会复杂声明的结合规则

**问题：** `int (*operation)(int, int)` 应该怎样阅读？指针、数组和函数声明中的括号、结合顺序与“优先级”是什么关系？

**核心答案：** C++ 声明使用的是声明符语法，不应机械套用普通表达式的运算符优先级表。阅读时从变量名开始向外展开：后缀 `()`、`[]` 比前缀 `*`、`&`、`&&` 绑定更紧，括号可以强制先把内部声明符组合起来，最左侧的基础类型最后读。

### 1. `int (*operation)(int, int)` 的含义

```cpp
int (*operation)(int, int);
```

从名字 `operation` 开始：

```text
operation
→ (*operation)             operation 是指针
→ (*operation)(int, int)   指向接受两个 int 参数的函数
→ int                      该函数返回 int
```

完整含义：

```text
operation 是一个指针，
它指向“接受两个 int 参数并返回 int”的函数。
```

### 2. 实际定义、赋值与调用

```cpp
int add(int left, int right)
{
    return left + right;
}

int (*operation)(int, int) = &add;

int result = operation(2, 3);
```

`result` 为 `5`。

函数名在这里可以转换为函数指针，因此也可以写：

```cpp
int (*operation)(int, int) = add;
```

调用时下面两种写法等价：

```cpp
operation(2, 3);
(*operation)(2, 3);
```

通常使用第一种。

### 3. 最重要的绑定规则

声明符中可以先记住三层：

| 层级 | 形式 | 含义 |
|---|---|---|
| 最先结合 | `name(...)` | `name` 是函数 |
| 最先结合 | `name[...]` | `name` 是数组 |
| 随后结合 | `*name` | `name` 是指针 |
| 随后结合 | `&name` | `name` 是左值引用 |
| 随后结合 | `&&name` | `name` 是右值引用 |
| 改变绑定 | `( ... )` | 强制内部先组成一个整体 |

简化为：

```text
函数 ()、数组 [] 比指针 *、引用 & 绑定更紧；
括号可以改变默认绑定。
```

### 4. 五步阅读法

遇到复杂声明：

1. 找到被声明的名字。
2. 从名字开始，在当前括号层向右看 `()` 或 `[]`。
3. 再向左看 `*`、`&`、`&&` 以及相应 `const`。
4. 离开当前括号，继续向外重复。
5. 最后读取最左侧基础类型。

可以把每一步翻译成一句中文，再组合起来。

### 5. 有括号与无括号完全不同

#### 函数指针

```cpp
int (*operation)(int, int);
```

从名字开始：

```text
operation → * → (int, int) → int
```

含义：

```text
指向函数的指针；
函数接受两个 int，返回 int。
```

#### 返回指针的函数

```cpp
int* operation(int, int);
```

由于 `()` 比 `*` 绑定更紧：

```text
operation → (int, int) → * → int
```

含义：

```text
operation 是函数；
函数接受两个 int，返回 int*。
```

对比：

```cpp
int (*operation)(int, int); // 指针，指向函数
int* operation(int, int);   // 函数，返回指针
```

关键区别就是：

```text
(*operation)
```

外面的括号。

### 6. 指针数组与数组指针

#### 指针数组

```cpp
int* values[4];
```

从 `values` 开始：

```text
values → [4] → * → int
```

含义：

```text
values 是含 4 个元素的数组；
每个元素都是 int*。
```

结构：

```text
values
├─ int*
├─ int*
├─ int*
└─ int*
```

#### 数组指针

```cpp
int (*values)[4];
```

从 `values` 开始：

```text
values → * → [4] → int
```

含义：

```text
values 是一个指针；
它指向“含 4 个 int 的数组”。
```

对比：

```cpp
int* values[4];   // 数组，元素是指针
int (*values)[4]; // 指针，指向数组
```

同样是括号改变了绑定。

### 7. 函数指针数组

```cpp
int (*operations[4])(int, int);
```

从 `operations` 开始：

```text
operations
→ [4]                    含 4 个元素的数组
→ *                      每个元素是指针
→ (int, int)             指向接受两个 int 的函数
→ int                    函数返回 int
```

完整含义：

```text
operations 是含 4 个函数指针的数组；
每个函数都接受两个 int，并返回 int。
```

示例：

```cpp
int add(int, int);
int subtract(int, int);

int (*operations[2])(int, int) = {
    &add,
    &subtract
};
```

### 8. 函数返回函数指针

直接声明可以写成：

```cpp
int (*choose_operation(bool use_add))(int, int);
```

从名字开始：

```text
choose_operation
→ (bool)                 是接受 bool 的函数
→ *                      返回指针
→ (int, int)             指针指向接受两个 int 的函数
→ int                    所指函数返回 int
```

虽然合法，但不易阅读。C++11 更推荐类型别名：

```cpp
using Operation = int (*)(int, int);

Operation choose_operation(bool use_add);
```

现在含义非常直接：

```text
choose_operation 接受 bool，返回 Operation。
```

### 9. C++11 的三种简化写法

#### `using` 类型别名

```cpp
using Operation = int (*)(int, int);

Operation operation = &add;
```

这是复杂函数指针接口最推荐的基础写法。

#### `auto`

```cpp
auto operation = &add;
```

编译器根据初始化器推导出函数指针类型。

#### `decltype`

```cpp
decltype(&add) operation = &add;
```

`&add` 的类型就是相应函数指针类型。

### 10. 尾置返回类型

C++11 可以用尾置返回类型简化“返回函数指针”的声明：

```cpp
auto choose_operation(bool use_add)
    -> int (*)(int, int);
```

仍然推荐在重复使用时配合别名：

```cpp
using Operation = int (*)(int, int);

Operation choose_operation(bool use_add);
```

### 11. 引用数组与引用函数

#### 数组引用

```cpp
int (&array_reference)[4] = array;
```

阅读：

```text
array_reference 是引用；
它引用一个含 4 个 int 的数组。
```

#### 函数引用

```cpp
int (&function_reference)(int, int) = add;
```

阅读：

```text
function_reference 是引用；
它引用接受两个 int 并返回 int 的函数。
```

### 12. `const` 与指针层级

```cpp
const int* first;
int* const second = nullptr;
const int* const third = nullptr;
```

含义：

```text
first  ：指向 const int 的指针
second ：指向 int 的 const 指针
third  ：指向 const int 的 const 指针
```

快速判断：

```text
const 在 * 左边 → 所指对象只读
const 在 * 右边 → 指针本身只读
```

完整类型别名会影响阅读：

```cpp
using IntPointer = int*;

const IntPointer pointer = nullptr;
```

这里 `pointer` 是：

```cpp
int* const
```

因为 `const` 限定整个 `IntPointer`，也就是指针本身。

### 13. 函数不能直接返回数组或函数

下面的目标不能直接写成“函数返回数组”或“函数返回函数”：

```text
函数不能直接返回数组类型；
函数不能直接返回函数类型。
```

但函数可以返回：

- 指向数组的指针。
- 数组的引用。
- 函数指针。
- 函数引用。
- `std::array` 等可以按值返回的类对象。

### 14. 快速对照表

| 声明 | 含义 |
|---|---|
| `int* p` | 指向 `int` 的指针 |
| `int a[4]` | 含 4 个 `int` 的数组 |
| `int* a[4]` | 含 4 个 `int*` 的数组 |
| `int (*p)[4]` | 指向“含 4 个 `int` 的数组”的指针 |
| `int f(int)` | 接受 `int`、返回 `int` 的函数 |
| `int* f(int)` | 接受 `int`、返回 `int*` 的函数 |
| `int (*p)(int)` | 指向“接受 `int`、返回 `int` 的函数”的指针 |
| `int (*a[4])(int)` | 含 4 个相应函数指针的数组 |
| `int (&r)[4]` | 对“含 4 个 `int` 的数组”的引用 |
| `int (&r)(int)` | 对“接受 `int`、返回 `int` 的函数”的引用 |

### 15. 三道即时判断

#### 第一题

```cpp
double* function(int);
```

答案：

```text
function 是函数；
接受一个 int；
返回 double*。
```

#### 第二题

```cpp
double (*pointer)(int);
```

答案：

```text
pointer 是指针；
指向接受一个 int 并返回 double 的函数。
```

#### 第三题

```cpp
double (*table[3])(int);
```

答案：

```text
table 是含 3 个元素的数组；
每个元素是函数指针；
所指函数接受 int 并返回 double。
```

### 16. 最终口诀

```text
从名字出发，先右后左，逐层向外；
() 和 [] 抢先结合；
*、&、&& 随后结合；
括号改变默认绑定；
基础类型最后读；
实际代码优先使用 using。
```

**一句话记忆：** `int (*operation)(int, int)` 从名字向外读就是“`operation` 是指针，指向接受两个 `int` 并返回 `int` 的函数”；去掉 `*operation` 外的括号，就会变成“函数返回指针”。

## W023：为什么有时 `sizeof(array)` 是整个数组，有时却是指针大小？

**关联题目：** 158（`a` 与 `&a` 的类型和移动步长）、163（二维数组与 `int**`）

**原题：** 给定 `int a[3];`，`a` 与 `&a` 的类型和移动步长有什么区别？

**原题答案：** 在会发生数组到指针转换的表达式中，`a` 转换为 `int*`，指向首元素；`&a` 的类型是 `int (*)[3]`，指向整个数组。`a + 1` 跨过一个 `int`，而 `&a + 1` 跨过整个含 3 个 `int` 的数组；二者地址数值起点可能相同，但类型和指针算术含义不同。

**问题：** `sizeof(array)` 为什么能够得到整个数组的大小？之前函数中的同样写法为什么只能得到指针大小？

**核心答案：** `sizeof` 是少数不会触发数组到指针转换的语境之一。如果当前表达式确实具有数组类型，`sizeof(array)` 得到整个数组对象的字节数；但函数形参中写出的 `T array[]` 会在函数类型形成时直接调整为 `T*`，因此函数体中的名字从一开始就是指针，不再是数组。

### 1. 真正的数组对象

```cpp
int array[10] = {};

sizeof(array);    // 整个 int[10] 数组的大小
sizeof(array[0]); // 一个 int 元素的大小
```

结果满足：

```cpp
sizeof(array) == 10 * sizeof(int);
```

原因不是 `sizeof` 根据指针猜出了数组长度，而是表达式 `array` 在这里仍具有类型：

```cpp
int[10]
```

`sizeof` 直接查询这个完整数组类型的大小。

### 2. 普通表达式中数组通常会转换为指针

```cpp
int array[10] = {};
int* pointer = array;
```

右侧 `array` 在该初始化语境中转换为指向首元素的指针：

```cpp
&array[0]
```

因此：

```cpp
sizeof(array);   // 整个数组大小
sizeof(pointer); // 指针对象自身大小
```

两者可能不同。例如在某个使用 4 字节 `int`、8 字节指针的平台上：

```text
sizeof(array)   = 40
sizeof(pointer) = 8
```

这些具体数字依赖实现，但两者查询的对象类型不同这一点不变。

### 3. 函数形参中的数组写法会调整为指针

```cpp
void inspect(int array[])
{
    sizeof(array); // 指针大小
}
```

函数形参声明中的：

```cpp
int array[]
```

会调整为：

```cpp
int* array
```

所以下面两个函数声明表示同一种函数类型：

```cpp
void first(int array[]);
void first(int* array);
```

进入函数体后，`array` 已经是一个按值传入的指针形参。因此：

```cpp
sizeof(array)
```

查询的是 `int*` 的大小。

关键区别：

```text
不是 sizeof 把函数形参数组转换成了指针；
而是数组形式的函数形参在更早的声明阶段就已经调整成了指针。
```

### 4. 形参方括号中写数字也不能保留长度

```cpp
void inspect(int array[100])
{
    sizeof(array); // 仍然是指针大小
}
```

普通函数形参中的 `100` 不会让参数按值携带一个完整的百元素数组，形参仍然调整为：

```cpp
int* array
```

它也不会自动进行运行期长度检查。

### 5. `sizeof(array) / sizeof(array[0])` 何时有效

```cpp
int array[10] = {};

std::size_t count =
    sizeof(array) / sizeof(array[0]);
```

这里结果为 `10`，因为当前作用域中的 `array` 是真正的数组。

但下面是错误用法：

```cpp
void inspect(int array[])
{
    std::size_t count =
        sizeof(array) / sizeof(array[0]);
}
```

这里实际计算：

```text
指针大小 / 一个 int 的大小
```

结果不是调用者数组的元素数量。

### 6. 函数怎样获得数组长度

#### 显式传入长度

```cpp
#include <cstddef>

void inspect(const int* data, std::size_t count)
{
}

int array[10] = {};
inspect(array, 10);
```

#### 使用数组引用保留长度

```cpp
void inspect(int (&array)[10])
{
    static_assert(
        sizeof(array) / sizeof(array[0]) == 10,
        "");
}
```

这里形参类型是：

```text
对含 10 个 int 元素的数组的引用
```

没有调整为指针，因此长度仍是类型的一部分。

#### 使用模板推导长度

```cpp
#include <cstddef>

template<class T, std::size_t N>
constexpr std::size_t array_size(T (&)[N])
{
    return N;
}

int array[10] = {};
static_assert(array_size(array) == 10, "");
```

模板参数 `N` 从数组类型中推导出来。

### 7. `std::array` 和 `std::vector` 不同

```cpp
#include <array>
#include <vector>

std::array<int, 10> fixed = {};
std::vector<int> dynamic(10);
```

- `fixed.size()` 返回 `10`。
- `sizeof(fixed)` 查询整个 `std::array` 对象大小。
- `dynamic.size()` 返回动态元素数量。
- `sizeof(dynamic)` 只查询 `std::vector` 管理对象自身大小，不包含动态分配的元素存储。

不要使用 `sizeof(container)` 代替容器的 `.size()`。

### 8. `sizeof` 返回的是字节数，不是元素数量

```cpp
std::size_t bytes = sizeof(array);
```

`sizeof` 的结果类型是 `std::size_t`，单位是 C++ 字节。C++ 保证：

```cpp
sizeof(char) == 1
```

但一个字节具体包含多少位由 `CHAR_BIT` 决定，不保证所有实现都为 8 位。

### 9. 最终对照

| 写法所在位置 | `array` 的实际类型 | `sizeof(array)` |
|---|---|---|
| `int array[10];` 所在作用域 | `int[10]` | 整个数组大小 |
| `int* pointer = array;` 中的 `pointer` | `int*` | 指针大小 |
| `void f(int array[])` 函数体 | `int*` | 指针大小 |
| `void f(int (&array)[10])` 函数体 | `int[10]` 的引用 | 整个数组大小 |

### 10. 对整个数组使用 `&` 也不会转换为首元素指针

```cpp
int array[10] = {};

int* first = array;          // array 转换为 &array[0]，类型为 int*
int (*whole)[10] = &array;   // 不转换，类型为 int (*)[10]
```

`array` 和 `&array` 表示的起始地址通常相同，但类型和指针运算不同：

```cpp
array + 1;  // 前进一个 int
&array + 1; // 前进整个 int[10] 数组
```

还要区分：

```cpp
sizeof(array);  // 整个数组大小
sizeof(&array); // 数组指针自身的大小
```

### 11. 第163题：二维数组不能当作 `int**`

**原题：** `int a[2][3]` 传入函数后可以安全地当作 `int**` 使用。

**原题答案：** 错误。二维内建数组的元素是 `int[3]`，转换后得到 `int (*)[3]`，即指向一整行的指针；`int**` 则指向一个 `int*` 对象，二者表示、类型和寻址方式都不同。强制把前者当后者使用不能修复类型不匹配，可能产生未定义行为。

类型变化：

```cpp
int a[2][3] = {};

// a 在通常表达式中转换为：
int (*row_pointer)[3] = a;

// 不能写：
// int** wrong = a;
```

内存含义：

```text
int a[2][3]
→ 两个连续的 int[3]
→ a + 1 前进一整行，即 3 个 int

int**
→ 指向一个 int* 对象
→ pointer + 1 前进一个 int* 的大小
```

正确的函数参数可以写成：

```cpp
void inspect(int (*a)[3], std::size_t rows);

// 等价的数组形参写法：
void inspect(int a[][3], std::size_t rows);
```

也可以用数组引用同时保留两维长度：

```cpp
void inspect(int (&a)[2][3]);
```

**一句话记忆：** 真数组遇到 `sizeof` 不会退化，所以得到整个数组大小；函数形参 `T array[]` 早已被调整成 `T*`，所以函数体内只能得到指针大小。

## W024：`sizeof`、`strlen`、C 字符串与 `std::string`

**问题：** `sizeof` 和 `strlen` 有什么本质区别？什么是 C 字符串？它与 C++11 的 `std::string` 在表示、长度、所有权、性能和接口使用上有什么区别？

**核心答案：**

- `sizeof` 查询静态类型对应的对象表示大小，单位是 C++ 字节；表达式操作数不被求值，结果类型为 `std::size_t`。
- `std::strlen` 接收 `const char*`，从该位置开始逐字节寻找第一个 `'\0'`，返回它之前的字符数量，不包含终止符。
- C 字符串不是独立类型，而是“以 `'\0'` 终止的连续 `char` 序列”这一内存约定。
- `std::string` 是拥有长度和资源管理能力的标准库类，保存的字符数量由 `size()` 记录，可以包含内嵌 `'\0'`。
- 日常 C++11 业务字符串优先使用 `std::string`；只有 C ABI、固定缓冲区或外部协议边界才通常需要直接处理 C 字符串。

### 1. 一张表先看懂全部区别

```cpp
#include <cstring>
#include <string>

char first[] = "abc";
char second[10] = "abc";
const char* pointer = "abc";
char raw[3] = {'a', 'b', 'c'};
std::string object = "abc";
std::string embedded("a\0b", 3);
```

| 表达式 | 结果或含义 |
|---|---|
| `sizeof("abc")` | `4`，字符串字面量类型为 `const char[4]` |
| `std::strlen("abc")` | `3`，不计算末尾 `'\0'` |
| `sizeof(first)` | `4`，整个数组大小 |
| `std::strlen(first)` | `3` |
| `sizeof(second)` | `10`，数组容量对应的总字节数 |
| `std::strlen(second)` | `3`，只扫描到第一个 `'\0'` |
| `sizeof(pointer)` | 指针对象自身大小 |
| `std::strlen(pointer)` | `3`，沿指针扫描字符串内容 |
| `sizeof(raw)` | `3` |
| `std::strlen(raw)` | 未定义行为，因为数组中没有 `'\0'` |
| `sizeof(object)` | `std::string` 管理对象自身大小 |
| `object.size()` | `3` |
| `embedded.size()` | `3`，包括中间的 `'\0'` |
| `std::strlen(embedded.c_str())` | `1`，扫描在内嵌 `'\0'` 处停止 |

### 2. `sizeof` 到底查询什么

```cpp
sizeof(expression);
sizeof(Type);
```

它返回对象表示占用的 C++ 字节数：

```cpp
int values[10] = {};

std::size_t array_bytes = sizeof(values);
std::size_t element_bytes = sizeof(values[0]);
```

数组满足：

```cpp
sizeof(values) == 10 * sizeof(int);
```

`sizeof` 根据表达式的类型工作，不读取字符串内容，也不会沿指针寻找结束位置。

不要把规则简化成“数组只在 `sizeof` 中不转换”。对整个数组使用一元 `&`、使用 `decltype(array)`、`typeid(array)` 或绑定到数组引用等语境，也会保留数组类型；数组到指针是按具体上下文发生的标准转换。

### 3. `sizeof` 的操作数不求值

```cpp
int value = 1;

sizeof(value = 9);

// value 仍然为 1
```

甚至：

```cpp
int* pointer = nullptr;

sizeof(*pointer); // 合法：不真正解引用 pointer
```

前提是 `*pointer` 所形成的类型允许应用 `sizeof`。这里查询的是 `int` 的大小，没有运行期空指针解引用。

### 3.1 `sizeof` 的类型限制与静态类型

不能直接对以下对象或类型使用标准 `sizeof`：

- `void`。
- 函数类型，但函数指针可以。
- 尚不完整的类型。
- 位域表达式。

类对象的 `sizeof` 包含实现为对齐加入的填充字节。通过引用使用时，结果是所引用类型的大小；对于多态对象，`sizeof` 仍按表达式的静态类型工作，不会在运行期根据最派生类型改变。

### 4. `sizeof` 返回的“字节”不保证是 8 位

C++ 保证：

```cpp
sizeof(char) == 1;
sizeof(signed char) == 1;
sizeof(unsigned char) == 1;
```

但一个 C++ 字节包含多少位由 `<climits>` 中的：

```cpp
CHAR_BIT
```

决定。常见平台为 8，但 ISO C++11 不强制所有平台都等于 8。

### 5. `sizeof` 不能告诉你动态分配长度

```cpp
char* buffer = new char[100];

sizeof(buffer); // 只是 char* 的大小

delete[] buffer;
```

指针只保存地址，不自动携带“后面有 100 个元素”的信息。相同问题也适用于：

```cpp
std::vector<int> values(100);

sizeof(values); // vector 管理对象大小，不是 100 个 int 的总大小
```

容器元素数量应使用：

```cpp
values.size();
```

### 6. `sizeof(std::string)` 为什么不是字符串长度

```cpp
std::string text = "hello";

sizeof(text); // std::string 对象自身大小
text.size();  // 5
```

`std::string` 对象通常包含指针、长度、容量或小字符串优化所需的内部状态，但具体布局由实现决定。`sizeof(text)` 不随文本长度变化：

```cpp
std::string short_text = "a";
std::string long_text(10000, 'x');

sizeof(short_text) == sizeof(long_text); // 同一类型的对象大小相同
```

长字符串使用的动态存储不包含在 `sizeof(std::string)` 的结果中。小字符串优化也只是常见实现策略，不是 C++11 必须采用的保证。

### 7. `strlen` 的函数模型

```cpp
#include <cstring>

std::size_t length = std::strlen(pointer);
```

可以概念性理解为：

```cpp
std::size_t string_length(const char* text)
{
    std::size_t length = 0;

    while (text[length] != '\0') {
        ++length;
    }

    return length;
}
```

真实标准库实现通常会进行优化，但语义上必须找到第一个 `'\0'`。

ISO C++11 的 C 字符串条款没有为 `strlen` 明写渐近复杂度保证，因此严格表述是“其语义要求确定第一个终止零的位置”；典型实现进行线性扫描，编译器也可能对已知内容进行内建优化或常量折叠。

### 8. `strlen` 的三个严格前提

调用：

```cpp
std::strlen(text);
```

要求：

1. `text` 不是空指针。
2. `text` 指向仍然存活、可读取的字符存储。
3. 从 `text` 开始，在可读取对象边界内能够遇到 `'\0'`。

错误示例：

```cpp
std::strlen(nullptr); // 未定义行为

char raw[3] = {'a', 'b', 'c'};
std::strlen(raw);     // 未定义行为：会继续越界寻找 '\0'
```

`strlen` 没有容量参数，因此无法自己阻止越界扫描。

### 9. `strlen` 不包含终止符

```cpp
char text[] = "abc";
```

内存为：

```text
索引： 0    1    2    3
内容：'a'  'b'  'c' '\0'
```

因此：

```cpp
sizeof(text)       == 4;
std::strlen(text)  == 3;
```

内嵌零也遵循“第一个零停止”：

```cpp
sizeof("\0")          == 2; // 显式零 + 自动附加的终止零
std::strlen("\0")     == 0;

sizeof("a\0b")        == 4; // 'a'、零、'b'、自动终止零
std::strlen("a\0b")   == 1;
```

复制完整 C 字符串所需容量至少为：

```cpp
std::strlen(text) + 1
```

多出的 `1` 用来保存终止空字符。

### 10. `'\0'`、`'0'` 和 `nullptr` 完全不同

```cpp
'\0'      // 数值为 0 的字符，用作 C 字符串终止符
'0'       // 数字字符 0，字符编码值通常不是 0
nullptr   // 空指针值
```

例如：

```cpp
char text[] = {'A', '0', 'B', '\0'};

std::strlen(text) == 3;
```

中间的 `'0'` 不是字符串终止符。

### 11. C 字符串不是一个独立类型

下面两个对象类型都是 `char[3]`：

```cpp
char valid[3] = {'A', 'B', '\0'};
char invalid[3] = {'A', 'B', 'C'};
```

但只有 `valid` 表示一个合法 C 字符串。是否为 C 字符串取决于：

```text
可访问范围内是否存在终止字符 '\0'
```

而不是仅由 `char*` 或 `char[]` 类型决定。

### 12. 字符串字面量与可修改字符数组

```cpp
const char* literal_pointer = "abc";
char modifiable[] = "abc";
```

`"abc"` 的类型是：

```cpp
const char[4]
```

字符串字面量具有静态存储期，不能修改：

```cpp
// literal_pointer[0] = 'A'; // 错误
```

`modifiable` 是独立的字符数组副本，可以修改：

```cpp
modifiable[0] = 'A'; // "Abc"
```

### 12.1 C 字符串指针不表达所有权

```cpp
const char* pointer = "abc";
```

这个指针只指向字符串字面量，不拥有它。普通 `char*` 或 `const char*` 本身也不能说明：

- 数据由谁分配。
- 应该由谁释放。
- 可写还是只读之外的容量是多少。
- 指针能够使用多久。

返回局部数组地址会形成悬空指针：

```cpp
const char* bad()
{
    char local[] = "abc";
    return local; // 错误：函数返回后 local 销毁
}
```

手工动态分配还要求正确配对：

```cpp
char* text = new char[capacity];
// ...
delete[] text;
```

日常 C++ 字符串优先用 `std::string`，让对象明确拥有并自动释放资源。

### 13. C 字符串的长度与容量必须分开

```cpp
char buffer[10] = "abc";
```

这里：

```text
数组容量：10 个 char
当前字符串长度：3
终止符占用：1
还能安全追加的普通字符数量：6
```

任何写操作必须保持：

```text
新长度 + 1 <= 容量
```

指针参数本身无法告诉函数容量：

```cpp
void write_text(char* destination);
```

更合理的接口应同时传入容量：

```cpp
void write_text(char* destination, std::size_t capacity);
```

### 14. 常见 C 字符串函数

```cpp
#include <cstring>
```

| 函数 | 作用 | 关键前提 |
|---|---|---|
| `strlen(s)` | 求第一个 `'\0'` 前的长度 | `s` 必须指向有效 C 字符串 |
| `strcmp(a, b)` | 按字典序比较 | 两者都必须有效 |
| `strchr(s, c)` | 查找字符 | `s` 必须有效 |
| `strstr(s, sub)` | 查找子串 | 两者都必须有效 |
| `strcpy(dst, src)` | 连同 `'\0'` 复制 | 目标容量足够且区域不重叠 |
| `strcat(dst, src)` | 追加字符串 | 目标原本有效且总容量足够 |
| `strncpy(dst, src, n)` | 最多按规则处理 `n` 个位置 | 不保证一定写入 `'\0'` |
| `memcpy(dst, src, n)` | 复制恰好 `n` 个字节 | 区域不能重叠 |
| `memmove(dst, src, n)` | 复制恰好 `n` 个字节 | 允许区域重叠 |

### 15. `strcmp` 的结果不是固定的 `-1/0/1`

```cpp
int result = std::strcmp(first, second);
```

只应判断：

```cpp
result < 0;  // first 在 second 前
result == 0; // 内容相等
result > 0;  // first 在 second 后
```

不能要求不同实现一定返回恰好 `-1` 或 `1`。

### 16. C 字符串不能用 `==` 比较内容

```cpp
char first[] = "abc";
char second[] = "abc";

bool same = first == second;
```

数组在比较中转换为指针，因此比较的是两个地址，不是内容。

内容比较要写：

```cpp
bool same =
    std::strcmp(first, second) == 0;
```

而 `std::string` 可以直接比较内容：

```cpp
std::string first = "abc";
std::string second = "abc";

bool same = first == second; // true
```

### 17. `strcpy` 和 `strcat` 的容量风险

```cpp
char destination[4];

std::strcpy(destination, "abcdef"); // 越界，未定义行为
```

`strcpy` 不知道目标容量。调用者必须保证：

```text
destination capacity >= strlen(source) + 1
```

`strcat` 需要保证：

```text
destination capacity
>= strlen(destination) + strlen(source) + 1
```

目标越界不是“字符串被截断”，而是未定义行为。

### 18. `strncpy` 不是自动安全版 `strcpy`

```cpp
char destination[4];

std::strncpy(destination, "abcdef", sizeof(destination));
```

当源字符串长度大于或等于 `n` 时，`strncpy` 可能不会写入末尾 `'\0'`。随后调用：

```cpp
std::strlen(destination);
```

可能越界扫描。

如果源字符串较短，`strncpy` 还会用零填充剩余位置，语义并不只是“最多复制若干字符”。不要因为函数名带 `n` 就默认它适合所有安全复制场景。

### 19. `memcpy` 与字符串复制不同

```cpp
char source[] = {'A', '\0', 'B'};
char destination[3];

std::memcpy(destination, source, 3);
```

`memcpy` 会复制全部三个字节，包括中间的零和后面的 `'B'`。它不寻找 `'\0'`，也不会自动追加终止符。

适合：

- 已知长度的字节块。
- 对象表示复制允许的场景。
- 可能包含零的二进制数据。

若源和目标范围重叠，应使用 `memmove`。

### 20. 重复调用 `strlen` 可能变成平方复杂度

不推荐：

```cpp
for (std::size_t index = 0;
     index < std::strlen(text);
     ++index) {
}
```

如果每轮都重新从头扫描，长度为 `N` 的字符串可能产生近似 `O(N²)` 工作量。

改为：

```cpp
const std::size_t length = std::strlen(text);

for (std::size_t index = 0;
     index < length;
     ++index) {
}
```

`std::string::size()` 在 C++11 中是常数时间，因此普通循环可以直接使用，但保存循环终点仍可能改善表达意图。

### 21. `std::string` 到底是什么

```cpp
#include <string>

std::string text = "hello";
```

`std::string` 是：

```cpp
std::basic_string<char>
```

它拥有一段数量可变的连续 `char` 序列，并负责所需存储的分配与释放。对象销毁时资源自动释放，体现 RAII。

与 `char*` 不同，`std::string` 在语义上同时管理：

- 字符序列。
- 当前字符数量。
- 可用容量。
- 动态资源生命周期。

### 22. `size()` 与 `length()` 完全等价

```cpp
std::string text = "hello";

text.size();   // 5
text.length(); // 5
```

C++11 规定：

```cpp
text.length() == text.size();
```

两者都是常数时间。通常容器风格代码使用 `size()`，强调文本语义时也有人使用 `length()`。

### 23. `size`、`capacity` 与 `sizeof`

```cpp
std::string text = "hello";
```

三者分别表示：

```text
text.size()      当前保存的 char 数量
text.capacity()  不重新分配时能够容纳的字符数量
sizeof(text)     std::string 管理对象自身的字节数
```

始终满足：

```cpp
text.size() <= text.capacity();
```

但不能假定：

```cpp
text.capacity() == text.size();
```

实现通常会预留额外容量，以减少连续追加时的重新分配。

### 24. `reserve`、`resize` 和 `shrink_to_fit`

```cpp
std::string text;

text.reserve(100); // 计划容纳至少 100 个字符
text.resize(20);   // 实际 size 变为 20
```

区别：

- `reserve(n)` 主要调整容量，不把逻辑长度直接改成 `n`。
- `resize(n)` 改变实际字符数量。
- 扩大 `resize` 时，新位置以指定字符或 `char()` 填充。
- `shrink_to_fit()` 只是非强制请求，实现可以不缩小容量。

### 25. `std::string` 可以包含内嵌 `'\0'`

```cpp
std::string text("A\0B", 3);

text.size() == 3;
text[0] == 'A';
text[1] == '\0';
text[2] == 'B';
```

因为 `std::string` 记录明确长度，不依赖第一个零判断结束位置。

但是：

```cpp
std::strlen(text.c_str()) == 1;
```

C API 只看到第一个 `'\0'` 前面的 `"A"`。

### 26. 两种构造函数对内嵌零的处理不同

```cpp
const char data[] = {'A', '\0', 'B'};

std::string first(data);    // 使用 C 字符串规则，size 为 1
std::string second(data, 3);// 明确复制 3 个字符，size 为 3
```

只传 `const char*` 的构造函数要求有效 C 字符串，并在第一个 `'\0'` 停止。传入指针和长度的构造函数复制准确数量的字符。

永远不要传空指针：

```cpp
const char* pointer = nullptr;

// std::string text(pointer); // 不满足前置条件
```

### 27. 重复字符构造的括号陷阱

```cpp
std::string first(5, 'x'); // "xxxxx"
```

C++11 还存在 `initializer_list` 构造函数，因此：

```cpp
std::string second{5, 'x'};
```

可能选择字符列表含义，形成两个字符，而不是五个 `'x'`。需要“数量 + 字符”构造时使用圆括号。

### 28. 复制与移动语义

复制具有值语义：

```cpp
std::string first = "abc";
std::string second = first;

second[0] = 'A';

// first 仍为 "abc"
// second 为 "Abc"
```

C++11 还支持移动：

```cpp
std::string target = std::move(source);
```

移动后 `source` 仍是有效对象，但值处于未指定状态；可以销毁、重新赋值或调用满足当前状态前提的操作，不能假定它一定为空。

### 29. 元素访问

```cpp
std::string text = "abc";

text[0];    // 'a'
text.at(0); // 'a'
```

区别：

- `operator[]` 不进行普通越界异常检查，基础代码只使用 `index < size()` 的索引。
- `at(index)` 在 `index >= size()` 时抛出 `std::out_of_range`。
- `front()` 和 `back()` 要求字符串非空。

C++11 中读取 `text[text.size()]` 会得到一个零值字符，但该位置不是普通字符串元素，修改它会产生未定义行为；`index > size()` 更不允许。基础代码坚持只访问 `[0, size())`。

```cpp
if (!text.empty()) {
    char first = text.front();
    char last = text.back();
}
```

### 30. 常见修改操作

```cpp
std::string text = "abc";

text += "def";
text.push_back('!');
text.append("XYZ");
text.insert(0, ">");
text.erase(0, 1);
text.replace(0, 3, "ABC");
text.clear();
```

`std::string` 会管理容量和终止字符，调用者不需要手工计算 `strlen + 1` 后分配。

### 31. 字符串拼接的常见错误

错误：

```cpp
// "hello" + "world"
```

两个操作数都是字符数组，转换后都是指针，C++ 没有两个指针相加的字符串拼接。

正确：

```cpp
std::string result =
    std::string("hello") + "world";
```

或者：

```cpp
std::string result = "hello";
result += "world";
```

循环中大量拼接时可先估算并 `reserve`，减少重新分配：

```cpp
std::string result;
result.reserve(expected_size);
```

### 32. 查找与子串

```cpp
std::string text = "hello world";

std::size_t position = text.find("world");

if (position != std::string::npos) {
    std::string part = text.substr(position, 5);
}
```

`find` 未找到时返回：

```cpp
std::string::npos
```

它不是普通的有效下标。

### 33. `std::string` 比较的是内容

```cpp
std::string first = "abc";
std::string second = "abc";

first == second; // true
first < second;  // 按字典序比较
```

比较会考虑明确的字符串长度和所有保存字符，包括内嵌 `'\0'`。

### 34. C++11 保证连续存储

`std::string` 的字符在 C++11 中连续存放，因此可以与需要只读连续字符的接口交互。

```cpp
const char* pointer = text.c_str();
```

`c_str()` 返回以零终止的字符序列指针：

```cpp
pointer[text.size()] == '\0';
```

C++11 中 `c_str()` 与 `data()` 都具有末尾零边界保证，并且都只返回只读指针：

```cpp
text.c_str(); // const char*
text.data();  // const char*
```

两者都不能通过返回指针修改字符。C++17 才为非 `const std::string` 增加可修改的 `data()` 重载。

流输出 `std::string` 使用对象记录的 `size()`，不会像 C 字符串函数那样在内嵌 `'\0'` 处截断：

```cpp
std::string text("A\0B", 3);
std::cout << text; // 向流写出三个 char；中间零通常没有可见字形
```

### 35. `c_str()` 指针何时失效

```cpp
const char* pointer = text.c_str();

text += "more";

// 不要继续假定 pointer 有效
```

会修改字符串、改变容量或把字符串传给接收非 `const std::string&` 的操作，都可能使之前取得的：

- `c_str()` 指针。
- `data()` 指针。
- 元素指针和引用。
- 迭代器。

失效。

安全基础规则：

```text
只在调用 C 接口前临时取得 c_str()；
字符串发生任何可能修改后重新取得。
```

### 36. 只读 C 接口

```cpp
void legacy_print(const char* text);

std::string value = "hello";
legacy_print(value.c_str());
```

如果 C 函数只在调用期间读取字符串，这种写法合适。

如果 C 函数会保存该指针，则必须额外保证：

- `std::string` 对象活得足够久。
- 保存期间字符串不发生使指针失效的修改。
- 对方不会通过指针修改字符。

### 37. 可写 C 接口

C++11 的 `c_str()` 和 `data()` 返回 `const char*`，不能传给需要写入的 `char*` 接口。

稳妥做法是准备独立缓冲区：

```cpp
#include <vector>

std::vector<char> buffer(
    text.begin(),
    text.end());

buffer.push_back('\0');

legacy_modify(buffer.data(), buffer.size());
```

修改后若接口保证存在终止符，可重新构造：

```cpp
std::string changed(buffer.data());
```

如果接口提供实际长度，优先使用长度构造：

```cpp
std::string changed(
    buffer.data(),
    actual_length);
```

对于确实需要原地写入的 C API，非空 `std::string` 的 `&text[0]` 在 C++11 中可以提供可写的连续字符区，但必须先把 `size()` 扩大到接口允许写入的全部槽位：

```cpp
const std::size_t buffer_size = 256;

std::string text;
text.resize(buffer_size); // 先形成 buffer_size 个实际字符位置

std::size_t actual_length =
    legacy_write(&text[0], text.size());

text.resize(actual_length);
```

不能因为 `capacity()` 足够就写到 `size()` 以外；如果 C API 还要写终止 `'\0'`，该槽位也必须包含在预先 `resize` 出来的区域内。由于接口契约很容易混淆，独立 `std::vector<char>` 缓冲区通常更稳妥。

### 38. 输入一个单词与输入整行

```cpp
std::string text;

std::cin >> text;
```

通常跳过开头空白，并读取到下一个空白为止。

读取整行：

```cpp
std::getline(std::cin, text);
```

它读取到换行分隔符并丢弃该分隔符。

混合使用时：

```cpp
int number = 0;
std::cin >> number;

std::cin.ignore(
    std::numeric_limits<std::streamsize>::max(),
    '\n');

std::getline(std::cin, text);
```

否则前一次格式化输入留下的换行可能让 `getline` 立即得到空行。

### 39. 数字与字符串转换

C++11 提供：

```cpp
int number = std::stoi("123");
double value = std::stod("3.14");
std::string text = std::to_string(42);
```

`stoi` 等函数可能抛出：

- `std::invalid_argument`：没有可解析转换。
- `std::out_of_range`：结果超出目标范围。

若需要确认整个字符串都被消费，可使用位置参数：

```cpp
std::size_t used = 0;
int value = std::stoi(text, &used);

bool consumed_all = used == text.size();
```

### 40. Unicode：长度不等于用户看到的字符数

`strlen` 和 `std::string::size()` 对 `std::string` 都按 `char` 单元计数，不理解 Unicode 字符或用户感知字符。

```cpp
std::string text = u8"中文";
```

UTF-8 中这两个汉字通常占 6 个字节，所以：

```cpp
text.size() == 6;
```

但用户看到的是两个汉字。一个 Unicode 字符还可能由多个码点组成，因此：

```text
字节数 ≠ Unicode 码点数 ≠ 用户感知字符数
```

按下标访问 UTF-8 `std::string` 可能只取得一个编码字节。

### 41. C 字符串、`std::string` 与二进制数据怎样选择

| 场景 | 推荐表示 |
|---|---|
| 普通 C++11 文本处理 | `std::string` |
| 只读函数参数，不需要保存 | `const std::string&` |
| C ABI 的只读字符串参数 | `string.c_str()` |
| C ABI 的可写缓冲区 | `std::vector<char>` 或明确的字符数组和容量 |
| 固定容量嵌入式缓冲区 | `char[N]`，同时严格跟踪长度与容量 |
| 任意二进制字节 | `std::vector<unsigned char>` 等明确字节容器 |
| 指针指向数据但长度单独提供 | `const char*` 加 `std::size_t` |

C++17 才提供标准 `std::string_view`；它不属于 C++11。

### 42. 容易混入 C++11 的后续版本特性

| 特性 | 标准版本 |
|---|---|
| `std::string` 移动语义、连续存储保证、`stoi`、`to_string` | C++11 |
| `"text"s` 字符串字面量后缀 | C++14 |
| `std::string_view` | C++17 |
| 非 `const std::string::data()` 返回可写指针 | C++17 |
| `starts_with`、`ends_with` | C++20 |
| `contains`、`resize_and_overwrite` | C++23 |

### 43. 最常见的错误清单

```text
1. 用 sizeof(pointer) 猜动态数组或字符串长度。
2. 对没有 '\0' 的字符数组调用 strlen。
3. 对 nullptr 调用 strlen 或构造 std::string。
4. 忘记 C 字符串容量必须包含终止符。
5. 使用 strcpy/strcat 却不检查目标容量。
6. 认为 strncpy 永远会写入 '\0'。
7. 使用 == 比较两个 C 字符串内容。
8. 把 sizeof(std::string) 当成字符数量。
9. 把 std::string::capacity() 当成 size()。
10. 认为 std::string 不能包含 '\0'。
11. 将 c_str() 指针保存到字符串修改之后。
12. 在 C++11 中通过 data() 或 c_str() 修改字符串。
13. 把 UTF-8 字节数当成用户字符数。
14. 在循环条件中反复调用 strlen，造成重复扫描。
```

### 44. 最终决策流程

看到“字符串长度”时依次问：

1. 当前对象是真数组、指针还是 `std::string`？
2. 需要的是对象占用字节数、数组容量，还是逻辑文本长度？
3. 如果使用 `strlen`，是否保证在边界内存在 `'\0'`？
4. 字符序列是否可能包含内嵌零？
5. 是否需要拥有数据，还是只借用指针？
6. 是否会调用可能保存或修改缓冲区的 C 接口？
7. 所谓“字符数”究竟是字节、编码单元、码点还是用户感知字符？

对应选择：

```text
对象表示大小       → sizeof
真数组元素数       → sizeof(array) / sizeof(array[0])
C 字符串首个零前长度 → strlen
std::string 字符单元数 → size()/length()
动态缓冲区容量       → 容器 capacity 或显式保存的容量
Unicode 用户字符数   → 需要专门的 Unicode 处理
```

**一句话记忆：** `sizeof` 看类型和对象表示，`strlen` 沿指针扫描到第一个 `'\0'`，`std::string::size()` 读取对象保存的明确长度；C 字符串靠终止符约定，`std::string` 靠长度与 RAII 管理字符序列。

## W025：什么是野指针？

**问题：** 什么是野指针？它与空指针、悬空指针有什么区别，通常怎样产生和避免？

**核心答案：** “野指针”不是 ISO C++11 的正式术语，通常泛指没有指向一个当前可合法访问对象、却可能被程序误用的指针。更准确的分类包括未初始化的指针、悬空指针和越界指针；使用它们解引用通常产生未定义行为。

### 1. 未初始化指针

```cpp
int* pointer;

// *pointer = 10; // 未定义行为
```

自动存储期局部指针没有初始化时保存不确定值。读取并把它当成有效地址使用是不正确的。

应初始化：

```cpp
int* pointer = nullptr;
```

### 2. 释放后形成悬空指针

```cpp
int* pointer = new int(5);

delete pointer;

// *pointer = 8; // 对象已销毁，未定义行为
```

`delete` 销毁对象并释放存储，但不会自动改写局部变量 `pointer`。它仍可能保存原来的地址，却不再指向一个存活的 `int` 对象。

可以立即写：

```cpp
pointer = nullptr;
```

但这只能清理当前变量，不能自动清理其他指向同一旧对象的别名。

### 3. 返回局部对象地址

```cpp
int* bad()
{
    int local = 3;
    return &local;
}
```

函数返回后 `local` 被销毁，返回的指针成为悬空指针。

通常应返回值：

```cpp
int good()
{
    int local = 3;
    return local;
}
```

### 4. 容器扩容使旧地址失效

```cpp
std::vector<int> values;
values.push_back(1);

int* pointer = &values[0];

values.push_back(2); // 可能重新分配

// pointer 可能已经失效
```

`std::vector` 重新分配存储后，旧元素指针、引用和迭代器会失效。

### 5. 越界指针

```cpp
int array[3] = {};

int* end = array + 3;
```

`end` 是合法的尾后一位指针，可以用于比较或表示范围终点，但不能解引用：

```cpp
// int value = *end; // 未定义行为
```

继续计算到数组允许范围之外的指针也不合法。

### 6. 空指针不是野指针

```cpp
int* pointer = nullptr;
```

空指针明确表示“不指向对象”，可以安全检查：

```cpp
if (pointer != nullptr) {
    use(*pointer);
}
```

但空指针仍然不能解引用。它与未初始化指针的区别是：空指针具有明确、可检测的状态。

### 7. 精确术语对照

| 状态 | 含义 |
|---|---|
| 未初始化指针 | 保存不确定值 |
| 空指针 | 明确不指向对象，可与 `nullptr` 比较 |
| 悬空指针 | 曾指向对象，但对象生命周期已经结束 |
| 尾后一位指针 | 可表示范围终点，但不能解引用 |
| 野指针 | 工程中的泛称，通常覆盖多种无效指针 |

### 8. 预防原则

```text
1. 指针声明时立即初始化。
2. 没有目标时使用 nullptr。
3. 不返回局部对象的地址或引用。
4. 明确对象所有权和生命周期。
5. 优先使用 std::unique_ptr、容器和 RAII。
6. delete 与 new、delete[] 与 new[] 正确配对。
7. 容器修改后重新确认旧指针、引用和迭代器是否有效。
8. 不解引用尾后一位指针或其他越界指针。
```

**一句话记忆：** 指针中有一个地址不代表该地址当前对应有效对象；解引用前必须同时确认指针已初始化、非空、在合法范围内，而且目标对象仍然存活。

## W026：块作用域、函数参数作用域、函数作用域、命名空间作用域和类作用域

**问题：** C++11 中这五种作用域分别表示什么？名字从哪里开始可见、在哪里结束，又有哪些常见混淆？

**核心答案：** 作用域描述“一个名字可以在哪段源代码中被查找到”。局部变量通常具有块作用域；形参具有函数参数作用域；函数作用域主要用于标签；命名空间成员具有命名空间作用域；类成员和嵌套类型具有类作用域。作用域不等于对象生命周期、链接属性或访问权限。

### 1. 先区分四个概念

| 概念 | 回答的问题 |
|---|---|
| 作用域 | 名字在哪里可以被查找到 |
| 存储期 | 对象的存储从何时存在到何时结束 |
| 链接 | 不同声明是否表示同一个实体 |
| 访问控制 | `public`、`protected`、`private` 是否允许访问 |

例如：

```cpp
void function()
{
    static int count = 0;
}
```

`count`：

- 名字具有块作用域，只能在相应块内直接使用。
- 对象却具有静态存储期，贯穿整个程序运行期。

所以“只能在函数内使用”不代表“每次调用都重新创建”。

### 2. 块作用域

由花括号形成的复合语句是典型的块：

```cpp
void function()
{
    int outer = 1;

    {
        int inner = 2;
        outer += inner;
    }

    // inner 在这里不可见
}
```

`inner` 的作用域从声明点开始，到内层 `}` 结束。`outer` 从自己的声明点开始，到函数体最外层 `}` 结束。

控制语句也会形成相应作用域：

```cpp
for (int index = 0; index < 3; ++index) {
    // index 可见
}

// index 不可见
```

### 3. 名字从声明点之后开始生效

```cpp
int value = 1;

{
    int value = value;
}
```

内层 `value` 的名字在其声明符之后已经进入作用域，所以初始化器右侧可能指向正在初始化的内层对象，而不是外层对象。这会读取尚未正确初始化的值。

不要写这种自遮蔽初始化：

```cpp
int value = value;
```

应使用不同名字或显式先保存外层值。

### 4. 内层块可以隐藏外层名字

```cpp
int value = 1;

void function()
{
    int value = 2;

    {
        int value = 3;
        // 使用最内层 value
    }

    // 使用函数体中的 value，值为2
}
```

这叫名字隐藏或遮蔽，不是重新修改了外层对象。全局命名空间中的名字可用：

```cpp
::value
```

显式访问。

### 5. 函数参数作用域

```cpp
int add(int left, int right)
{
    return left + right;
}
```

在函数定义中，形参 `left`、`right` 从各自声明点开始，作用域延伸到函数体结束。

形参是函数调用时建立的局部对象：

```cpp
void change(int value)
{
    value = 10;
}
```

按值形参 `value` 是独立副本。

### 6. 函数声明中的形参名字只用于说明

```cpp
int add(int left, int right);
```

如果这里只是声明，形参名字的作用域不会延伸到其他代码。名字甚至可以省略：

```cpp
int add(int, int);
```

定义中的形参名字也可以不同：

```cpp
int add(int first, int second)
{
    return first + second;
}
```

函数类型取决于参数类型，不取决于形参名字。

### 7. 形参不能在函数最外层块中重复声明

```cpp
void function(int value)
{
    // int value = 3; // 错误：与形参重复

    {
        int value = 3; // 内层块可以遮蔽，但通常不推荐
    }
}
```

为了可读性，通常避免用内层变量隐藏形参。

### 8. C++11 尾置返回类型可以使用形参名字

```cpp
auto copy(int value) -> decltype(value)
{
    return value;
}
```

解析尾置返回类型时，形参 `value` 已经声明，因此可在 `decltype(value)` 中使用。

### 9. 函数作用域主要用于标签

C++ 中“函数作用域”不是说所有函数局部变量都具有函数作用域。普通局部变量是块作用域。

具有函数作用域的典型名字是 `goto` 标签：

```cpp
void function(bool stop)
{
    if (stop) {
        goto finished;
    }

    // 其他代码

finished:
    return;
}
```

标签可以在声明位置之前被 `goto` 引用，因为标签名字在整个函数中有效。

标签不能跨越函数使用：

```cpp
void first()
{
target:
    return;
}

void second()
{
    // goto target; // 错误：target 属于另一个函数
}
```

即使标签名字在整个函数中可见，`goto` 仍不能非法跳过需要初始化的对象并进入其作用域。

### 10. 命名空间作用域

```cpp
namespace application {
    int value = 1;

    void run()
    {
        ++value;
    }
}
```

`value` 和 `run` 是命名空间成员，可通过限定名访问：

```cpp
application::value;
application::run();
```

全局名字实际上位于全局命名空间：

```cpp
int global_value = 0;
```

可写：

```cpp
::global_value
```

开头没有名字的 `::` 表示从全局命名空间开始查找，从而绕过当前块、形参或类中的同名名字。它不限于变量：

```cpp
::global_function();
::GlobalType object;
::std::cout << global_value;
```

对比：

```text
::value       全局命名空间中的 value
app::value    命名空间 app 中的 value
Class::value  类 Class 中的成员名字
this->value   当前对象的非静态成员 value
```

`::` 只改变名字查找起点，不会绕过链接、定义或访问控制规则。

### 11. 命名空间可以重新打开

```cpp
namespace application {
    void first();
}

namespace application {
    void second();
}
```

这两个代码块属于同一个 `application` 命名空间，不是两个不同命名空间。

C++11 嵌套命名空间需要写：

```cpp
namespace company {
namespace project {
    int value = 0;
}
}
```

下面的简写属于 C++17：

```cpp
// namespace company::project { }
```

### 12. 命名空间作用域不等于外部链接

```cpp
namespace {
    int hidden = 0;
}
```

`hidden` 具有命名空间作用域，但匿名命名空间使其只在当前翻译单元中具有相应可见实体。

同样：

```cpp
const int limit = 10;
```

命名空间作用域的非 `extern const` 对象在 C++ 中默认具有内部链接。

所以：

```text
作用域描述名字在哪里可见；
链接描述跨声明、跨翻译单元是否为同一实体。
```

### 13. 类作用域

```cpp
class Student {
public:
    using Id = int;

    void set_score(int score)
    {
        this->score = score;
    }

private:
    Id id = 0;
    int score = 0;
};
```

`Id`、`set_score`、`id` 和 `score` 都是类 `Student` 作用域中的名字。

类外可以使用限定名：

```cpp
Student::Id identifier = 1;
```

但能否访问某个成员还要经过 `public`、`protected`、`private` 检查。

### 14. 类作用域与访问权限不同

```cpp
class Example {
private:
    int value = 0;
};
```

`value` 确实属于 `Example` 的类作用域，但类外普通代码不能访问它，是因为访问控制，不是因为它“不在类作用域中”。

### 15. 形参可以隐藏数据成员

```cpp
class Student {
public:
    void set_score(int score)
    {
        this->score = score;
    }

private:
    int score = 0;
};
```

函数体中的普通名字：

```cpp
score
```

优先表示形参。成员使用：

```cpp
this->score
```

明确指定。

### 16. 类外定义成员函数

```cpp
class Counter {
public:
    void increment();

private:
    int value = 0;
};

void Counter::increment()
{
    ++value;
}
```

虽然函数体写在类定义外，`Counter::increment` 的函数体仍处于相应成员函数语境，可以直接查找类成员 `value`。

### 17. 派生类名字会隐藏基类同名成员

```cpp
class Base {
public:
    void function(int);
};

class Derived : public Base {
public:
    void function(double);
};
```

`Derived::function` 会在名字查找阶段隐藏基类中的同名集合。需要时可以：

```cpp
using Base::function;
```

把基类重载引入派生类作用域。

### 18. 五种作用域总表

| 作用域 | 典型声明 | 基本范围 |
|---|---|---|
| 块作用域 | `{ int value; }` | 声明点到当前块末尾 |
| 函数参数作用域 | `void f(int value)` | 参数声明点到函数定义末尾；纯声明中到声明结束 |
| 函数作用域 | `label:` | 整个当前函数，主要用于标签 |
| 命名空间作用域 | `namespace app { int value; }` | 相应命名空间中的声明区域，可通过限定名查找 |
| 类作用域 | `class C { int value; };` | 类成员声明和相应成员语境 |

### 19. 最终判断方法

看到一个名字时依次问：

```text
1. 它声明在哪一种作用域中？
2. 当前使用位置位于其声明点之后吗？
3. 是否被更内层同名声明隐藏？
4. 是否需要 namespace::name、Class::name、this->name 或 ::name？
5. 即使能找到名字，对象是否仍然存活？
6. 即使能找到成员，访问权限是否允许？
7. 跨源文件使用时，链接和定义是否正确？
```

**一句话记忆：** 局部变量看花括号，形参看到函数体结束，函数作用域主要管标签，命名空间成员用 `namespace::name`，类成员用 `Class::name` 或 `this->name`；可见性、生命周期、链接和访问权限必须分开判断。

## W027：C++11 的四种存储期

**问题：** 自动存储期、静态存储期、线程存储期和动态存储期分别是什么？它们与作用域、对象生命周期及常见的“栈/堆”说法有什么区别？

**核心答案：** 存储期描述对象所占存储从什么时候可用到什么时候结束。自动存储期通常持续到当前块或函数调用结束；静态存储期覆盖整个程序运行期；线程存储期覆盖当前线程运行期且每个线程有独立对象；动态存储期由显式分配与释放或 RAII 所有者控制，不与创建它的块自动同步结束。

### 1. 一段代码看全四种

```cpp
#include <memory>

int global_value = 0;                 // 静态存储期
thread_local int thread_value = 0;    // 线程存储期

void function(int parameter)          // parameter：自动存储期
{
    int local = 0;                    // 自动存储期
    static int calls = 0;             // 静态存储期
    thread_local int local_thread = 0;// 线程存储期

    int* raw = new int(5);            // *raw：动态存储期
    delete raw;

    std::unique_ptr<int> owner(
        new int(6));                   // 所管对象：动态存储期
}
```

特别注意：

```text
raw 指针变量本身是自动存储期；
new int(5) 创建的目标对象是动态存储期。
```

指针和所指对象可以具有不同存储期。

### 2. 自动存储期

典型对象：

- 普通块作用域局部变量。
- 函数按值形参。
- 未声明为 `static`、`thread_local` 或指向其他实体的普通局部对象。

```cpp
void function(int parameter)
{
    int local = 1;
}
```

每次调用函数都会建立本次调用对应的 `parameter` 和 `local` 对象；离开相应块时对象销毁。

```cpp
void recursive(int depth)
{
    int value = depth;

    if (depth > 0) {
        recursive(depth - 1);
    }
}
```

每一层递归调用都有自己独立的 `value`。

### 3. 自动存储期不等于标准保证的“栈”

工程上常说局部变量位于栈上，但 ISO C++11 描述的是自动存储期，并不强制实现必须使用某种名为“栈”的硬件或内存结构。

编译器可能：

- 把对象放进调用栈。
- 把值放入寄存器。
- 优化掉不需要实际存储的对象。

所以严谨术语是“自动存储期对象”。

### 4. 自动局部基础类型默认可能未初始化

```cpp
void function()
{
    int value;
    int* pointer;

    // 读取 value 或 pointer 的不确定值是错误的
}
```

应初始化：

```cpp
int value = 0;
int* pointer = nullptr;
```

自动存储期本身不保证普通基础类型自动清零。

### 5. 静态存储期

典型对象：

- 命名空间作用域变量。
- 使用 `static` 声明的局部对象。
- 类的静态数据成员对应的对象。
- 字符串字面量。

```cpp
int global_value = 0;

void function()
{
    static int calls = 0;
    ++calls;
}
```

这些对象的存储贯穿整个程序运行期。

### 6. 局部静态对象只创建一次

```cpp
void function()
{
    static int calls = 0;
    ++calls;
}
```

多次调用：

```cpp
function();
function();
function();
```

三个调用使用同一个 `calls` 对象，值会持续保留，而不是每次重新创建。

这里：

- `calls` 的名字具有块作用域。
- `calls` 对象具有静态存储期。

再次说明作用域与存储期不是同一概念。

### 7. 局部静态对象何时初始化

```cpp
Object& instance()
{
    static Object object;
    return object;
}
```

函数局部静态对象通常在控制第一次经过声明时初始化。C++11 保证并发线程到达该初始化时，初始化过程按规则只完成一次。

如果初始化抛出异常，本次初始化没有成功，之后再次经过声明时可以重新尝试。

### 8. 静态存储期对象的零初始化

```cpp
int global_value;

void function()
{
    static int local_static;
}
```

没有显式初始化器时，这些静态存储期整数会先被零初始化：

```text
global_value == 0
local_static == 0
```

这与未初始化的普通自动局部 `int` 不同。

### 9. 静态初始化顺序风险

同一翻译单元和不同翻译单元中的命名空间作用域对象具有初始化顺序规则；跨翻译单元让一个全局对象的动态初始化依赖另一个全局对象，容易产生初始化顺序问题。

常见规避方式：

```cpp
Object& get_object()
{
    static Object object;
    return object;
}
```

把依赖对象放在函数局部静态对象中，首次实际使用时初始化。

### 10. `static` 关键字不只表示存储期

```cpp
static int namespace_value;
```

命名空间作用域中的 `static` 还会影响链接。

```cpp
class Example {
    static int count;
};
```

类中的 `static` 表示成员不属于某个单独对象。

因此看到 `static` 时要根据上下文判断它对存储期、链接或类成员语义的影响。

### 11. 线程存储期

使用：

```cpp
thread_local int counter = 0;
```

线程存储期对象：

- 每个线程各自拥有一份独立对象。
- 当前线程通过名字访问自己的那一份。
- 存储通常持续到当前线程结束。
- 在线程结束时销毁对应对象。

示意：

```text
线程A：counter = 3
线程B：counter = 8
线程C：counter = 0
```

它们不是同一个共享整数。

### 12. 块作用域的 `thread_local`

```cpp
void process()
{
    thread_local int calls = 0;
    ++calls;
}
```

`calls`：

- 名字只在 `process` 的相应块内可见。
- 每个线程分别拥有自己的 `calls`。
- 同一线程多次调用 `process` 时，该线程的值持续保留。

### 13. `thread_local` 不等于线程安全共享

`thread_local` 通过“每个线程独立一份”避免直接共享同一个对象，但它不能自动解决其他共享数据上的竞争。

如果多个线程仍然访问同一个普通全局对象，就可能需要：

- `std::mutex`。
- `std::atomic`。
- 其他同步设计。

### 14. 动态存储期

```cpp
int* pointer = new int(5);

delete pointer;
```

动态对象的存储从分配成功开始，直到正确释放。

它不会因为创建它的代码块结束而自动销毁：

```cpp
int* create()
{
    int* pointer = new int(5);
    return pointer;
}
```

函数返回后，指针变量 `pointer` 销毁，但动态整数仍然存在。调用者必须承担释放责任。

### 15. 动态数组必须正确配对

```cpp
int* one = new int(5);
delete one;

int* many = new int[10];
delete[] many;
```

必须配对：

```text
new    ↔ delete
new[]  ↔ delete[]
```

配错、重复释放或释放后继续使用都会造成未定义行为。

### 16. 动态存储期的三个典型问题

#### 内存泄漏

```cpp
void function()
{
    int* pointer = new int(5);
} // pointer消失，但动态对象没有释放
```

#### 悬空指针

```cpp
int* pointer = new int(5);
delete pointer;

// pointer仍保存旧地址，但对象已销毁
```

#### 重复释放

```cpp
delete pointer;
// delete pointer; // 未定义行为
```

### 17. C++11 优先使用 RAII

```cpp
#include <memory>

std::unique_ptr<int> pointer(
    new int(5));
```

`std::unique_ptr` 销毁时自动释放所拥有对象：

```cpp
void function()
{
    std::unique_ptr<int> pointer(
        new int(5));
} // 自动释放
```

动态数组和顺序元素通常优先使用：

```cpp
std::vector<int> values(10);
```

而不是手工管理 `new[]`。

### 18. 存储期与对象生命周期

两者密切相关但不是完全相同概念：

- 存储期描述原始存储存在多久。
- 对象生命周期描述某种类型的对象何时开始存在、何时可以合法使用、何时结束。

普通代码中初始化成功后生命周期开始，析构时结束；放置 `new`、联合体等低层场景会让两者区别更加明显。

### 19. 四种存储期总表

| 存储期 | 典型声明 | 数量 | 结束时间 |
|---|---|---|---|
| 自动 | 普通局部变量、形参 | 每次进入或调用各一份 | 离开相应块或调用结束 |
| 静态 | 全局变量、局部 `static` | 整个程序通常一份相应对象 | 程序结束 |
| 线程 | `thread_local` | 每个线程一份 | 对应线程结束 |
| 动态 | `new` 创建的对象 | 每次成功分配一份 | `delete`、RAII释放或泄漏到进程结束 |

### 20. 最终判断法

看到一个对象时依次问：

```text
1. 名字在哪个作用域可见？
2. 对象是哪一种存储期？
3. 对象生命周期是否已经开始？
4. 对象是否已经销毁？
5. 谁拥有它并负责释放？
6. 指针变量与所指对象是否具有不同存储期？
7. 多线程下是一份共享对象，还是每线程一份？
```

**一句话记忆：** 普通局部对象随块自动结束，全局和 `static` 对象贯穿程序，每个 `thread_local` 对象随各自线程存在，`new` 出来的对象则必须由 `delete` 或 RAII 所有者结束。

## W028：`class`、`struct` 与静态成员函数

**问题：** `class` 和 `struct` 的默认规则有什么差异？为什么静态成员函数没有 `this`？局部名字遮蔽成员时怎样使用 `this->member`？

**核心答案：**

- `class` 的成员默认是 `private`，默认继承方式也是 `private`。
- `struct` 的成员默认是 `public`，默认继承方式也是 `public`。
- 静态成员函数不依附某个具体对象调用，因此没有指向“当前对象”的 `this` 指针。
- 形参或局部变量与数据成员同名时，未限定名字优先表示更近的形参或局部变量；使用 `this->member` 可以明确访问当前对象的成员。

### 1. `class` 与 `struct`

```cpp
class A
{
    int value; // 默认 private
};

struct B
{
    int value; // 默认 public
};
```

继承时也有默认差异：

```cpp
class Base
{
};

class DerivedA : Base   // 默认 private 继承
{
};

struct DerivedB : Base  // 默认 public 继承
{
};
```

显式写出访问权限或继承方式后，就按显式规则处理：

```cpp
class C
{
public:
    int value;
};

class DerivedC : public Base
{
};
```

`class` 和 `struct` 的能力基本相同：二者都可以拥有数据成员、成员函数、构造函数、析构函数、访问控制和继承关系。不能把 `struct` 理解成“只能存放数据”。

### 2. 静态成员函数为什么没有 `this`

```cpp
class Counter
{
public:
    static void reset_total()
    {
        total = 0;      // 正确：访问静态数据成员
        // value = 0;   // 错误：没有具体对象
    }

private:
    int value = 0;      // 每个对象各有一份
    static int total;   // 整个类共享
};
```

普通非静态成员函数通过隐含的 `this` 知道当前操作哪个对象：

```cpp
void set(int value)
{
    this->value = value;
}
```

静态成员函数可以直接通过类名调用：

```cpp
Counter::reset_total();
```

调用时没有提供某个 `Counter` 对象，因此不存在“当前对象”，也就没有 `this`。它可以直接访问静态成员；如果需要访问非静态成员，必须显式取得一个对象、引用或指针。

### 3. 局部名字遮蔽成员时使用 `this->member`

```cpp
class Student
{
public:
    void set_score_wrong(int score)
    {
        score = score;
    }

    void set_score(int score)
    {
        this->score = score;
    }

    int get_score() const
    {
        return score;
    }

private:
    int score = 0;
};
```

在 `set_score_wrong` 中，形参也叫 `score`。形参处于更近的函数参数作用域，会遮蔽同名数据成员。因此：

```cpp
score = score;
```

左右两边都表示形参，相当于把形参赋给它自己，当前对象的数据成员完全没有改变。它通常可以通过编译，所以容易形成逻辑错误。

在普通非静态成员函数中：

```cpp
this
```

指向当前调用对象。因此：

```cpp
this->score = score;
```

可以明确区分：

```text
this->score  → 当前 Student 对象的数据成员
score        → 函数形参
```

调用示例：

```cpp
Student student;
student.set_score(90);

// student.get_score() == 90
```

局部变量也可能遮蔽成员：

```cpp
class Example
{
public:
    void function()
    {
        int value = 20;

        // value       表示局部变量，值为 20
        // this->value 表示数据成员，值为 10
    }

private:
    int value = 10;
};
```

还可以通过避免同名来消除遮蔽：

```cpp
void set_score(int new_score)
{
    score = new_score;
}
```

这里没有局部名字叫 `score`，因此未限定的 `score` 可以找到数据成员。

注意：这通常不是编译器无法选择的“二义性”。名字查找已经选择了更近的局部名字；`this->member` 的作用是明确访问被遮蔽的数据成员。

**一句话记忆：** 形参和成员同名时，裸名字找形参，`this->成员` 找当前对象；`class` 默认私有、`struct` 默认公有，静态成员函数没有 `this`。

## W029：C++11 的 `friend` 友元语法

**问题：** `friend` 怎样声明友元函数、友元类和指定的友元成员函数？友元拥有什么权限，又有哪些限制？

**核心答案：** `friend` 声明写在类定义内部，用于授权指定函数或类访问当前类的 `private` 和 `protected` 成员。友元获得访问权限，但不会因此成为当前类的成员；友元关系不传递、不继承，也不自动互为友元。

### 1. 友元函数

```cpp
#include <iostream>

class Box
{
    friend void print(const Box& box);

private:
    int value = 7;
};

void print(const Box& box)
{
    std::cout << box.value << '\n';
}
```

语法：

```cpp
class ClassName
{
    friend ReturnType function(Parameters);
};
```

`print` 可以访问 `Box::value`，但它仍然是普通非成员函数：

- 没有隐含的 `this`。
- 调用写成 `print(box)`，不是 `box.print()`。
- 必须通过参数等方式取得需要访问的对象。

### 2. 在类内直接定义友元函数

```cpp
class Point
{
public:
    Point(int x, int y)
        : x(x), y(y)
    {
    }

    friend bool equal(const Point& left, const Point& right)
    {
        return left.x == right.x &&
               left.y == right.y;
    }

private:
    int x;
    int y;
};
```

在类定义内部定义的这种友元函数是非成员函数，并隐含具有 `inline` 属性。实际工程中通常仍需合理安排命名空间声明，使普通名字查找和接口位置清晰。

### 3. 友元类

```cpp
class Inspector;

class Vault
{
    friend class Inspector;

private:
    int secret = 42;
};

class Inspector
{
public:
    int inspect(const Vault& vault) const
    {
        return vault.secret;
    }
};
```

语法：

```cpp
class Owner
{
    friend class FriendClass;
};
```

这会让 `Inspector` 的成员函数都能够按规则访问 `Vault` 的非公有成员。它不会让 `Vault` 自动成为 `Inspector` 的友元。

### 4. 只授权另一个类的某个成员函数

如果不想把整个类都设为友元，可以只授权指定成员：

```cpp
class Vault;

class Inspector
{
public:
    int inspect(const Vault& vault) const;
};

class Vault
{
    friend int Inspector::inspect(const Vault& vault) const;

private:
    int secret = 42;
};

int Inspector::inspect(const Vault& vault) const
{
    return vault.secret;
}
```

语法：

```cpp
friend ReturnType ClassName::member(Parameters) qualifiers;
```

由于编译器必须先知道这个成员函数确实存在，所以相关类和成员声明的先后顺序很重要。

### 5. 友元模板

可以授权一族模板实例：

```cpp
template<class T>
class Inspector;

class Vault
{
    template<class T>
    friend class Inspector;

private:
    int secret = 42;
};
```

这表示 `Inspector<T>` 的各个相应实例都是 `Vault` 的友元。模板友元还可以只授权特定实例，但声明和定义依赖关系更复杂，应在掌握模板后使用。

### 6. `friend` 放在 `public`、`private` 还是 `protected`

下面两种授权效果相同：

```cpp
class A
{
public:
    friend void first(A&);
};

class B
{
private:
    friend void second(B&);
};
```

友元声明放在哪个访问区域，不改变授权效果。通常按项目风格把友元声明集中放置。

### 7. 友元关系的四个重要限制

#### 不自动互为友元

```text
A 把 B 设为友元
不代表 B 把 A 设为友元
```

#### 不传递

```text
B 是 A 的友元
C 是 B 的友元
不能推出 C 是 A 的友元
```

#### 不继承

某个类是友元，不代表它的派生类自动得到同样权限。

#### 友元不是成员

友元函数不会获得 `this`，也不能使用 `object.friend_function()` 的成员调用语法。

### 8. 典型使用场景

- 对称的二元运算符，例如 `operator==`。
- 流输出运算符，例如 `operator<<`，因为左操作数是输出流。
- 与类实现紧密配合的工厂或辅助函数。
- 必须读取内部表示的少量协作类。

不要为了省略正常接口而大量使用友元。过多友元会扩大能够破坏类不变量的代码范围，并增加类之间的耦合。

**一句话记忆：** `friend` 写在被访问的类中，只授予非公有成员访问权；友元不是成员，关系不互惠、不传递、不继承。

## W030：类为什么不能直接包含自身对象

**问题：** 为什么类不能直接包含 `Node next;`，却可以包含 `Node* next;`？

**核心答案：** 非静态对象成员直接嵌入外围对象内部，因此编译器必须知道成员的完整大小。若 `Node` 直接包含另一个 `Node`，计算一个 `Node` 的大小又需要先计算内部 `Node` 的大小，递归永远无法结束。指针的大小由指针类型和实现决定，不取决于目标对象有多大，所以在 `Node` 尚未完整时也能声明 `Node*` 成员。

### 1. 直接包含自身对象不合法

```cpp
class Node
{
    Node next; // 错误：Node 在这里仍是不完整类型
};
```

对象成员直接存放在外围对象内部。假设忽略对齐和填充：

```text
sizeof(Node)
= sizeof(next)
= sizeof(Node)
```

而内部的 `next` 又包含自己的 `next`，因此所需大小没有终点。编译器无法确定应该为一个 `Node` 对象分配多少存储。

下面同样不合法：

```cpp
class Node
{
    Node children[2]; // 仍然直接嵌入 Node 对象
};
```

### 2. 指针成员合法

```cpp
class Node
{
public:
    int value = 0;
    Node* next = nullptr;
};
```

这里一个 `Node` 对象只直接包含：

```text
一个 int 对象
一个 Node* 指针对象
```

`Node*` 自身具有固定大小。它只保存另一个 `Node` 对象的地址，目标对象并没有嵌入当前对象内部：

```text
Node A ──next──> Node B ──next──> Node C
```

因此链表可以拥有任意多个节点，但每个节点对象本身的大小仍然固定。

### 3. 指针不自动表示所有权

```cpp
Node* next = nullptr;
```

只表示可以保存地址，不能单独说明：

- 当前节点是否拥有下一个节点。
- 谁负责创建和销毁下一个节点。
- 指针是否可能悬空。

C++11 中需要表达独占所有权时可以使用：

```cpp
#include <memory>

class Node
{
public:
    int value = 0;
    std::unique_ptr<Node> next;
};
```

这样当前节点拥有 `next` 指向的节点，当前节点销毁时会沿所有权关系自动清理后续节点。

### 4. 引用也可以引用自身类型

```cpp
class Node
{
public:
    explicit Node(Node& other)
        : next(other)
    {
    }

private:
    Node& next;
};
```

引用成员不把另一个完整 `Node` 嵌入当前对象，而只是绑定到外部已有对象，因此类型层面允许；但引用必须在构造时绑定，而且目标必须比引用活得更久。

**一句话记忆：** `Node next` 表示“对象里面完整放另一个 Node”，导致大小无限递归；`Node* next` 表示“这里只放一个地址”，所以大小固定。

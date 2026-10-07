# Velvet Language Documentation

Velvet is a fast, powerful, and intuitive programming language designed with an object-oriented foundation, rich asynchronous support, and native embedded markup (VML).

---

## 1. Variables and Data Types
Velvet supports both dynamic variables (using `auto`) and statically typed variables.

```velvet
auto name = "Alice"      // Dynamically inferred type
String greeting = "Hi"   // Statically enforced type
Number age = 25
Boolean isTrue = true
```

## 2. Control Flow

### If / Else
```velvet
if (age > 18) {
    print("Adult")
} else {
    print("Minor")
}
```

### Loops
Velvet has traditional `while` loops, but also introduces the powerful `loop` keyword for bounded iterations.
```velvet
// Runs exactly 10 times. 'i' is the loop index (0 to 9)
loop (10, i) {
    print("Iteration: " + i)
}

// While loop
auto count = 0
while (count < 5) {
    count = count + 1
}
```

## 3. Functions
Functions in Velvet are defined using the `fn` keyword.

```velvet
fn greet(name) {
    return "Hello " + name
}

// Functions can also be marked as async
async fn fetchData(url) {
    // ...
}
```

## 4. Classes and Object-Oriented Programming
Velvet is highly object-oriented. Classes can define properties, static methods, and instance methods. The constructor in Velvet is always named `init`.

```velvet
class Person {
    String name = ""
    Number age = 0

    // Constructor
    fn init(name, age) {
        this.name = name
        this.age = age
    }

    fn sayHello() {
        print("Hello, my name is " + this.name)
    }

    // Static functions do not require an instance
    static fn createDefault() {
        return new Person("Default", 0)
    }
}

auto p = new Person("Bob", 30)
p.sayHello()
```

## 5. Async / Await
Velvet fully supports modern asynchronous programming. Any function interacting with IO, networks, or timers should be awaited.

```velvet
import "io.velv"

async fn readFile() {
    auto file = new File("data.txt")
    if (await file.exists()) {
        auto content = await file.readAsString()
        print(content)
    }
}
```

## 6. Collections (Lists and Maps)
Velvet has native built-in syntax for lists and maps, which act as dynamic collections.

### Lists
```velvet
auto fruits = ["Apple", "Banana", "Cherry"]
fruits.add("Orange")
print(fruits.get(0)) // "Apple"
```

### Maps
```velvet
auto config = {
    "host": "localhost",
    "port": 8080
}
print(config.get("host"))
config.put("timeout", 5000)
```

## 7. Error Handling (Try / Catch)
You can safely catch runtime errors using `try`/`catch`. To throw a custom error, use the `throw` keyword.

```velvet
try {
    throw "Something went wrong!"
} catch (e) {
    print("Error caught: " + e)
}
```

## 8. Embedded VML (Velvet Markup Language)
Velvet supports native inline markup without needing external HTML files. This is powered by VML.
Markup is identified by the `@` symbol.

```velvet
import "vml.velv"

auto source = '
@document(lang="en") {
    @head {
        @title { My App }
    }
    @body(theme="dark") {
        @main(id="content") {
            @h1 { Welcome to Velvet! }
        }
    }
}'

// Parse it into an interactive DOM
auto dom = VML.parse(source)
auto doc = dom.nodes[0]

// Interactively query and mutate it!
auto mainNode = doc.findId("content")
mainNode.append(VML.parse('@p { New paragraph added dynamically! }').nodes[0])

print(doc.toHTML())
```

## 9. Native Bindings
Velvet allows direct binding to underlying native runtime methods using the `outer fn` keyword in core library files. This allows the Velvet interpreter to map directly to Dart functions.

```velvet
class NativeExample {
    // This tells Velvet that the implementation is provided natively by the runtime environment
    outer fn doSomethingNative(arg1)
}
```

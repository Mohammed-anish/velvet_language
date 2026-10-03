# Velvet Language Guide (A-Z Complete Reference)

Velvet is a fast, dynamically-typed scripting language with native interoperability, built on top of Dart. This guide is the **complete, A-to-Z reference** for Velvet's syntax and capabilities. 

> [!TIP]
> **Core Libraries:** Velvet also includes a massive built-in Standard Library (e.g., `os`, `io`, `socket`, `json`). Please refer to `Velvet_Core_Documentation.md` for the full A-Z list of all available core classes and methods.

---

## 1. Variables & Data Types

Velvet supports both explicit typing and type-inference via the `auto` keyword. 

### Data Types
- `String`: Text strings, surrounded by single (`'`) or double (`"`) quotes.
- `Number`: Integers and floating-point numbers.
- `boolean`: `true` or `false`.
- `List`: Arrays of items (e.g., `[1, 2, 3]`).
- `Map`: Key-value dictionaries (e.g., `{"key": "value"}`).

### Variable Declaration
```typescript
// Explicitly typed
String msg = 'Hello from Velvet!'
Number count = 42
boolean isEnabled = true
List names = ['Alice', 'Bob']
Map config = {"theme": "dark"}

// Inferred typing (Recommended)
auto dynamicVar = 10
auto active = false
```

### String Interpolation
You can inject variables directly into strings using `${}`.
```typescript
String myName = "Velvet"
print("Hello ${myName}, welcome!")
```

### State (Enums)
Velvet has a dedicated `state` keyword to define enumerations of possible values.
```typescript
state Status {
    Idle
    Loading
    Success
    Error
}

auto currentStatus = Status.Loading
```

---

## 2. Control Flow

### If / Else
Standard comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`) and logical operators (`&&`, `||`, `!`) are fully supported.
```typescript
auto count = 15

if (count >= 10 && !false) {
    print('Count is high')
} else if (count == 5) {
    print('Count is exactly 5')
} else {
    print('Count is low')
}
```

### Loops (`for`, `while`, `loop`)
Velvet provides traditional loops, as well as a simplified `loop` syntax.

```typescript
// 1. Standard For Loop
for (auto i = 0; i < 10; i = i + 1) {
    print(i)
}

// 2. While Loop
auto x = 5
while (x > 0) {
    print(x)
    x = x - 1
}

// 3. Simplified 'loop' syntax: loop (iterations, indexVariableName)
loop (5, i) {
    print('Iteration: ' + i)
}
```

### Try / Catch / Throw
You can throw custom strings or objects, and catch them gracefully to prevent crashes.
```typescript
try {
    throw 'Oops, something went wrong!'
} catch (e) {
    print('Caught an error: ' + e)
}
```

---

## 4. Functions

Functions are declared using the `fn` keyword. They can accept arguments and return values.

```typescript
// Standard function
fn calculateSum(a, b) {
    return a + b
}

auto result = calculateSum(10, 5)
print(result) // 15
```

---

## 5. Object-Oriented Programming (Classes)

Velvet is strictly object-oriented. Classes can have fields, constructors, instance methods, static methods, and can inherit from other classes!

### Basic Class Syntax
```typescript
class Person {
    String name = ""
    Number age = 0

    // Constructor is ALWAYS named 'init'
    fn init(n, a) {
        this.name = n
        this.age = a
    }

    fn sayHello() {
        print('Hello from ' + this.name)
    }

    // Static methods are called on the class itself
    static fn getSpecies() {
        return 'Human'
    }
}

// Instantiation uses the 'new' keyword
auto p = new Person('Velvet', 1)
p.sayHello()
print(Person.getSpecies())
```

### Class Inheritance (`derives`)
You can inherit fields and methods from a parent class using the `derives` keyword.

```typescript
class Employee derives Person {
    String role = ""

    fn init(n, a, r) {
        this.name = n
        this.age = a
        this.role = r
    }
    
    fn sayRole() {
        print('I am an ' + this.role)
    }
}

auto emp = new Employee('Alice', 25, 'Engineer')
emp.sayHello() // Inherited from Person!
emp.sayRole()  // From Employee
```

---

## 6. Reactive State (`reactive` & `watch`)

Velvet has a powerful built-in reactivity system. You can mark variables as `reactive` and `watch` them. Whenever the variable changes, the `watch` block automatically re-executes!

```typescript
reactive auto counter = 0

// This block will run immediately, and then again EVERY time counter changes!
watch counter {
    print('The counter is now: ' + counter)
}

counter = 1 // Automatically triggers the watch block
counter = 2 // Automatically triggers the watch block
```

---

## 7. Dynamic Evaluation (`eval`)

Velvet can dynamically evaluate strings containing Velvet code at runtime. `eval` operates within the current local scope, meaning injected variables are accessible after `eval()` executes!

```typescript
auto secret = 'Local scope variable'
eval("print(secret)") // Has access to local scope

eval("auto injected = 'Hello World'")
print(injected) // Prints 'Hello World'
```

---

## 8. Importing Modules and Libraries

Velvet bundles a massive standard library (Core APIs) directly into the executable. 

### Importing Core Libraries
To import a core library (like `io`, `socket`, `os`), simply use its name **without** an extension.
```typescript
import "object"
import "io"
import "json"
import "os"
import "socket"
import "ai"
```

### Importing Local Files
To import your own Velvet scripts, use the full filename with the `.velv` extension.
```typescript
import "my_utils.velv"
import "network/client.velv"
```

> [!IMPORTANT]
> To see the full list of available core libraries and their methods, read the `Velvet_Core_Documentation.md` file!

---

## 9. Custom Syntax Extensions (Actions)

Velvet features an incredibly powerful metaprogramming system called **Actions**. Actions allow you to define entirely new syntax for your language without modifying the compiler!

Actions are defined in special `.action.velv` files inside your project directory. 

### Defining an Action
To define a new syntax rule, use an `actions { ... }` block. You can define what parameters your new syntax takes (e.g., `string`, `block`, `expression`, `identifier`).

**`http.action.velv`:**
```typescript
actions {
    // Defines a new keyword 'fetch' that takes a URL string and a code block
    fetch(url: string, body: block) {
        http.get(url, body) // Transforms it into normal Velvet code
    }

    // Defines a new keyword 'log' that takes a single expression
    log(value: expression) {
        print(value)
    }
}
```

### Using an Action
Once defined in a `.action.velv` file, the Velvet compiler automatically registers this new syntax. You can use it natively in any `.velv` file!

**`main.velv`:**
```typescript
// Uses the custom 'log' syntax
log "Starting the application..."
log 10 + 20

// Uses the custom 'fetch' syntax
fetch "https://example.com" {
    print("Fetched successfully!")
}
```

When Velvet compiles `main.velv`, it automatically transforms `fetch "https://..." { ... }` into `http.get("https://...", { ... })` before executing it!

---

## 9. Native Dart Interop (Outer Bindings)

Velvet allows you to bind native Dart code directly into Velvet classes using the `outer` keyword. This allows Velvet to be easily extended with native performance features.

**In Velvet (`my_math.velv`):**
```typescript
class MathUtils {
    // Declared as an outer native method. There is no body.
    static outer fn nativeMultiply(a, b)
}
```

**In Dart (Interpreter Side):**
```dart
Runtime.register("MathUtils", (klass) {
    klass.defineStatic('nativeMultiply', (args) {
        return (args[0] as num) * (args[1] as num);
    });
});
```

When a Velvet script calls `MathUtils.nativeMultiply(5, 5)`, it will instantly route out to the native Dart implementation and return the result!

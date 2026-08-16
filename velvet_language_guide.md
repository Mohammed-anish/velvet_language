# Velvet Language Guide (Complete Reference)

Velvet is a dynamically-typed scripting language with native interoperability, built on top of Dart. This document serves as the **complete** reference for Velvet's syntax, core libraries, and capabilities, which you can provide to any AI to write accurate Velvet code.

## 1. Basics & Types

Velvet supports both explicit typing and type-inference via the `auto` keyword. 

### Variables
```typescript
// Explicitly typed
String msg = 'Hello from Velvet!'
Number count = 42
Map config = {"theme": "dark"}
List names = ['Alice', 'Bob']
boolean isEnabled = true

// Inferred typing
auto dynamicVar = 10
```

### String Interpolation
Velvet supports standard string interpolation using `${}`.
```typescript
String myName = "Velvet"
Number year = 2026
print("Hello ${myName}, welcome to ${year}!")
```

## 2. Control Flow

### If / Else
Supports standard comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`) and logical operators (`&&`, `||`, `!`).
```typescript
if (count >= 10 && !false) {
    print('Count is high')
} else {
    print('Count is low')
}
```

### Loops (For, While, Loop)
Velvet provides `for`, `while`, and a special `loop` syntax.
```typescript
// Standard For Loop
for (auto i = 0; i < 10; i = i + 1) {
    print(i)
}

// While Loop
while (count > 0) {
    count = count - 1
}

// Special 'loop' syntax: loop (iterations, indexVariableName)
loop (5, i) {
    print('Iteration: ' + i)
}
```

### Try / Catch / Throw
Exceptions can be thrown as expressions and caught.
```typescript
try {
    throw 'Oops something went wrong!'
} catch (e) {
    print('Caught error: ' + e)
}
```

## 3. Functions
Functions are declared using the `fn` keyword.
```typescript
fn sum(a, b) {
    return a + b
}
auto result = sum(10, 5)
```

## 4. Object-Oriented Programming (Classes)
Velvet is strictly object-oriented. Classes can have fields, constructors (`init`), instance methods, and static methods.

```typescript
class Person {
    String name = ""

    // Constructor is always named 'init'
    fn init(n) {
        this.name = n
    }

    fn sayHello() {
        print('Hello from ' + this.name)
    }

    static fn getSpecies() {
        return 'Human'
    }
}

// Instantiation using 'new'
auto obj = new Person('Velvet')
obj.sayHello()

print(Person.getSpecies())
```

## 5. Reactive State (`reactive` & `watch`)
Velvet supports built-in state reactivity. You can declare a variable as `reactive` and `watch` it for changes. Whenever the variable is updated, the `watch` block automatically re-executes.

```typescript
reactive auto counter = 0

watch counter {
    print('Counter changed to: ' + counter)
}

counter = 1 // Automatically triggers the watch block above
```

## 6. Built-in Core Types and Methods

### `Object`
- `string()`: Converts object to a string.
- `hash()`: Returns hashcode number.

### `String`
- `toUpperCase()`, `toLowerCase()`
- `length()`
- `trim()`
- `split(pattern)`
- `replace(from, to)`
- `contains(substring)`
- `startsWith(prefix)`, `endsWith(suffix)`
- `substring(start, end)`
- `isEmpty()`

### `Number`
- `toString()`
- `toInt()`, `toDouble()`
- `round()`, `floor()`, `ceil()`, `abs()`

### `List` (Arrays)
- `add(item)`
- `get(index)`
- `set(index, value)`
- `length()`

*Note: Lists also support bracket indexing: `list[0]`.*

### `Map`
- `put(key, value)`
- `get(key)`

*Note: Maps also support bracket indexing: `map['key'] = 'val'`.*

## 7. Built-in System Functions
- `print(value)`: Prints a value to the standard output.
- `ofile(path)`: Synchronously reads an entire file at `path` and returns its contents as a String.

## 8. Core Modules (APIs)
Velvet has several core modules that must be imported to use.

### Importing
```typescript
import "bin/velvet_core/object.velv"
import "bin/velvet_core/io.velv"
import "bin/velvet_core/json.velv"
import "bin/velvet_core/os.velv"
```

### File System (Requires `io.velv`)
```typescript
auto file = new File('test_file.txt')

if (!file.exists()) {
    file.create()
}

file.writeAsString('Hello')
file.appendAsString(' World!')
print(file.readAsString())
file.delete()
```

### HTTP Requests (Requires `io.velv`)
```typescript
auto http = new Http()
auto response = http.get('https://api.ipify.org', {})
print('Status: ' + response['statusCode'])
print('Response: ' + response['body'])
```

### JSON Parsing (Requires `json.velv`)
```typescript
auto json = new JSON()
Map myMap = {"name": "Velvet", "year": 2026}

// Stringify
String jsonStr = json.stringify(myMap)

// Parse
auto parsedMap = json.parse(jsonStr)
print(parsedMap['year'])
```

### Operating System & Process (Requires `os.velv`)
```typescript
print(Platform.os())               // e.g. "macos"
print(Platform.env('PATH'))        // Fetch Environment variable

print(Process.cwd())               // Current working directory
Process.sleep(1000)                // Sleep for 1 second

// Join and extract paths
auto joined = Path.join('folder', 'file.txt')
print(Path.basename(joined))
```

### Dates and Timers
```typescript
auto dt = DateTime.now()
print(dt.year())
print(dt.month())
print(dt.toIso8601String())

// Timers accept the name of a callback function as a string
fn timerCallback() {
    print('Timer fired!')
}
Timer.delayed(500, 'timerCallback')
Timer.periodic(1000, 'timerCallback')
```

### Eval
Velvet can dynamically evaluate strings containing Velvet code. `eval` operates within the current local scope, meaning injected variables are accessible after `eval()` executes.
```typescript
auto secret = 'Local scope variable'
eval("print(secret)")
eval("auto injected = 'Hello'")
print(injected) // Prints 'Hello'
```

## 9. Native Dart Interop (Outer Bindings)
Velvet supports registering native Dart functions and objects via the `outer` keyword.

**In Velvet:**
```typescript
class MathUtils {
    // Declared as an outer native method
    static outer fn nativeMultiply(a, b)
}
```

**In Dart (Interpreter Side):**
```dart
Runtime.register("MathUtils", (klass) {
    klass.defineStatic('nativeMultiply', (args) => (args[0] as num) * (args[1] as num));
});
```

Raw Dart objects returned from outer methods can also be directly interacted with inside Velvet, provided their class structure has been defined in a `.velv` file (using `Runtime.bindPrimitive`).

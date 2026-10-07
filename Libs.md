# Velvet Core Libraries

This document contains the complete documentation for all built-in core libraries in Velvet.

## Module: `ai`
---

### Class: `SimpleAI`
**Properties:**
- `_inputs`
- `_outputs`

**Methods:**
- `init()`
- `save(filepath)`
- `load(filepath)`
- `learn(inputs, outputs)`
- `predictTrend(yValues, futureX)`
- `predict(inputData)`
- `group(dataList, k)`
- `recommend(userPreferences, allAvailableItems)`
- `_euclideanDistance(a, b)`


## Module: `async`
---

### Class: `Timer`
**Methods:**
- `static sleep(milliseconds)`


## Module: `binary`
---

### Class: `Buffer`
**Methods:**
- `static alloc(size)`
- `static fromUtf8(string)`
- `toUtf8()`
- `length()`
- `get(index)`
- `set(index, value)`


## Module: `collections`
---

### Class: `Collections`
**Methods:**
- `static size(list)`
- `static isEmpty(list)`
- `static contains(list, value)`
- `static indexOf(list, value)`
- `static first(list)`
- `static last(list)`
- `static add(list, value)`
- `static remove(list, value)`
- `static reverse(list)`
- `static copy(list)`
- `static join(list, separator)`
- `static sum(list)`
- `static product(list)`
- `static min(list)`
- `static max(list)`
- `static average(list)`
- `static sort(list)`
- `static sortDescending(list)`
- `static chunk(list, size)`
- `static range(start, end)`
- `static unique(list)`
- `static zip(first, second)`
- `static slice(list, start, end)`


### Class: `Stack`
**Properties:**
- `items`

**Methods:**
- `init()`
- `push(value)`
- `pop()`
- `peek()`
- `isEmpty()`
- `size()`
- `clear()`
- `values()`


### Class: `Queue`
**Properties:**
- `items`

**Methods:**
- `init()`
- `enqueue(value)`
- `dequeue()`
- `peek()`
- `isEmpty()`
- `size()`
- `clear()`
- `values()`


### Class: `Set`
**Properties:**
- `items`

**Methods:**
- `init()`
- `add(value)`
- `remove(value)`
- `contains(value)`
- `indexOf(value)`
- `size()`
- `isEmpty()`
- `clear()`
- `values()`
- `union(other)`
- `intersection(other)`
- `difference(other)`
- `string()`


### Class: `LinkedListNode`
**Properties:**
- `value`
- `next`

**Methods:**
- `init(value)`


### Class: `LinkedList`
**Properties:**
- `head`
- `tail`
- `count`

**Methods:**
- `init()`
- `add(value)`
- `addFirst(value)`
- `removeFirst()`
- `first()`
- `last()`
- `size()`
- `isEmpty()`
- `clear()`
- `values()`


## Module: `dns`
---

### Class: `DNS`
**Methods:**
- `static lookup(host)`


## Module: `ffi`
---

### Class: `FFI`
**Methods:**
- `static load(path, libName)`
- `static invokeVoid(libName, funcName)`
- `static invokeInt(libName, funcName, arg)`
- `static invokeString(libName, funcName, arg)`


## Module: `http_server`
---

### Class: `HttpServer`
**Methods:**
- `static bind(host, port)`
- `accept()`
- `close()`


### Class: `HttpRequest`
**Methods:**
- `method()`
- `uri()`
- `path()`
- `query()`
- `headers()`
- `ip()`
- `response()`
- `readAsString()`
- `readAsBytes()`
- `parseJson()`
- `parseFormUrlEncoded()`
- `parseMultipart()`


### Class: `HttpResponse`
**Methods:**
- `statusCode()`
- `setStatusCode(code)`
- `setHeader(name, value)`
- `removeHeader(name)`
- `write(data)`
- `writeBytes(buffer)`
- `close()`


## Module: `io`
---

### Class: `File`
**Properties:**
- `path`

**Methods:**
- `init(path)`
- `create()`
- `delete()`
- `exists()`
- `readAsString()`
- `writeAsString(content)`
- `appendAsString(content)`
- `readAsBytes()`
- `writeAsBytes(buffer)`
- `copy(newPath)`
- `rename(newPath)`


### Class: `Folder`
**Properties:**
- `path`

**Methods:**
- `init(path)`
- `create(recursive)`
- `delete(recursive)`
- `exists()`
- `list(recursive)`
- `static current()`


### Class: `Http`
**Methods:**
- `static get(url, headers)`
- `static post(url, body, headers)`
- `static put(url, body, headers)`
- `static delete(url, headers)`


## Module: `json`
---

### Class: `JSON`
**Methods:**
- `stringify(map)`
- `parse(string)`


## Module: `math`
---

### Class: `Math`
**Methods:**
- `static abs(x)`
- `static sign(x)`
- `static min(a, b)`
- `static max(a, b)`
- `static clamp(value, minimum, maximum)`
- `static square(x)`
- `static cube(x)`
- `static average(a, b)`
- `static lerp(a, b, t)`
- `static sqrt(value)`
- `static cbrt(value)`
- `static pow(base, exponent)`
- `static squareRoot(value)`
- `static floor(x)`
- `static ceil(x)`
- `static round(x)`
- `static trunc(x)`
- `static radians(degrees)`
- `static degrees(radians)`
- `static normalizeRadians(angle)`
- `static sin(angle)`
- `static cos(angle)`
- `static tan(angle)`
- `static atan(x)`
- `static atan2(y, x)`
- `static asin(x)`
- `static acos(x)`
- `static exp(x)`
- `static ln(value)`
- `static log10(value)`
- `static log2(value)`
- `static sinh(x)`
- `static cosh(x)`
- `static tanh(x)`
- `static distance2D(x1, y1, x2, y2)`
- `static distance3D(x1, y1, z1, x2, y2, z2)`
- `static hypot(x, y)`
- `static factorial(n)`
- `static permutation(n, r)`
- `static combination(n, r)`
- `static gcd(a, b)`
- `static lcm(a, b)`
- `static smoothstep(edge0, edge1, x)`
- `static smootherstep(edge0, edge1, x)`


## Module: `object`
---

### Class: `Object`
**Methods:**
- `string()`
- `hash()`


### Class: `List`
**Methods:**
- `add(item)`
- `get(index)`
- `set(index, value)`
- `length()`
- `remove(item)`
- `removeAt(index)`
- `contains(item)`
- `indexOf(item)`
- `clear()`


### Class: `Map`
**Methods:**
- `put(key, value)`
- `get(key)`
- `remove(key)`
- `containsKey(key)`
- `keys()`
- `values()`
- `clear()`


### Class: `Error`
**Properties:**
- `message`

**Methods:**
- `init(message)`


### Class: `String`
**Methods:**
- `toUpperCase()`
- `toLowerCase()`
- `length()`
- `trim()`
- `split(pattern)`
- `replace(from, to)`
- `contains(substring)`
- `startsWith(prefix)`
- `endsWith(suffix)`
- `substring(start, end)`
- `isEmpty()`


### Class: `Number`
**Methods:**
- `toString()`
- `toInt()`
- `toDouble()`
- `round()`
- `floor()`
- `ceil()`
- `abs()`


### Class: `Boolean`
**Methods:**
- `toString()`


## Module: `os`
---

### Class: `Process`
**Methods:**
- `static run(command, args)`
- `static args()`
- `static cwd()`
- `static sleep(milliseconds)`
- `static exit(code)`


### Class: `Platform`
**Methods:**
- `static env(key)`
- `static os()`


### Class: `Path`
**Methods:**
- `static join(part1, part2)`
- `static basename(path)`
- `static dirname(path)`
- `static extension(path)`


### Class: `DateTime`
**Methods:**
- `static now()`
- `year()`
- `month()`
- `day()`
- `hour()`
- `minute()`
- `second()`
- `millisecondsSinceEpoch()`
- `toIso8601String()`


### Class: `Timer`
**Methods:**
- `static periodic(milliseconds, functionName)`
- `static delayed(milliseconds, functionName)`


## Module: `physics`
---

### Class: `PhysicsMath`
**Methods:**
- `static abs(x)`
- `static min(a, b)`
- `static max(a, b)`
- `static clamp(value, minValue, maxValue)`
- `static sqrt(value)`
- `static radians(degrees)`
- `static degrees(radians)`
- `static normalizeAngle(angle)`
- `static sin(angle)`
- `static cos(angle)`


### Class: `Vector2`
**Properties:**
- `x`
- `y`

**Methods:**
- `init(xValue, yValue)`
- `add(other)`
- `subtract(other)`
- `multiply(scalar)`
- `divide(scalar)`
- `magnitude()`
- `magnitudeSquared()`
- `normalize()`
- `dot(other)`
- `distanceTo(other)`
- `angle()`
- `string()`


### Class: `Kinematics`
**Methods:**
- `static velocity(distance, time)`
- `static distance(velocity, time)`
- `static acceleration(initialVelocity, finalVelocity, time)`
- `static finalVelocity(initialVelocity, acceleration, time)`
- `static displacement(initialVelocity, acceleration, time)`
- `static finalVelocityFromDistance(initialVelocity, acceleration, distance)`
- `static averageVelocity(initialVelocity, finalVelocity)`
- `static freeFallDistance(time, gravity)`
- `static freeFallVelocity(time, gravity)`


### Class: `Force`
**Methods:**
- `static fromMassAndAcceleration(mass, acceleration)`
- `static acceleration(force, mass)`
- `static weight(mass, gravity)`
- `static earthWeight(mass)`
- `static friction(coefficient, normalForce)`
- `static spring(springConstant, displacement)`
- `static centripetal(mass, velocity, radius)`
- `static gravitational(mass1, mass2, distance)`


### Class: `Energy`
**Methods:**
- `static kinetic(mass, velocity)`
- `static gravitationalPotential(mass, height, gravity)`
- `static earthPotential(mass, height)`
- `static springPotential(springConstant, displacement)`
- `static work(force, distance)`
- `static power(workValue, time)`
- `static efficiency(usefulEnergy, inputEnergy)`


### Class: `Momentum`
**Methods:**
- `static linear(mass, velocity)`
- `static impulse(force, time)`
- `static change(initialMomentum, finalMomentum)`
- `static inelasticCollision(mass1, velocity1, mass2, velocity2)`


### Class: `CircularMotion`
**Methods:**
- `static velocity(radius, period)`
- `static period(radius, velocity)`
- `static frequency(period)`
- `static acceleration(velocity, radius)`
- `static angularVelocity(period)`


### Class: `Projectile`
**Methods:**
- `static horizontalVelocity(initialVelocity, angle)`
- `static verticalVelocity(initialVelocity, angle)`
- `static flightTime(initialVelocity, angle, gravity)`
- `static maximumHeight(initialVelocity, angle, gravity)`
- `static range(initialVelocity, angle, gravity)`
- `static x(initialVelocity, angle, time)`
- `static y(initialHeight, initialVelocity, angle, time, gravity)`


### Class: `Rotation`
**Methods:**
- `static torque(radius, force, angle)`
- `static angularAcceleration(torque, inertia)`
- `static finalAngularVelocity(initialAngularVelocity, angularAcceleration, time)`


### Class: `Fluid`
**Methods:**
- `static pressure(force, area)`
- `static density(mass, volume)`
- `static hydrostaticPressure(density, depth, gravity)`
- `static buoyantForce(fluidDensity, displacedVolume, gravity)`


### Class: `PhysicsUnits`
**Methods:**
- `static kmhToMs(speed)`
- `static msToKmh(speed)`
- `static degreesToRadians(degrees)`
- `static radiansToDegrees(radians)`
- `static gramsToKilograms(grams)`
- `static kilogramsToGrams(kilograms)`
- `static centimetersToMeters(centimeters)`
- `static metersToCentimeters(meters)`


### Class: `Physics`
**Methods:**
- `static kineticEnergy(mass, velocity)`
- `static potentialEnergy(mass, height)`
- `static force(mass, acceleration)`
- `static weight(mass)`
- `static momentum(mass, velocity)`
- `static gravitationalForce(mass1, mass2, distance)`
- `static distance(initialVelocity, acceleration, time)`
- `static velocity(initialVelocity, acceleration, time)`


## Module: `probability`
---

### Class: `Probability`
**Methods:**
- `static probability(favorable, total)`
- `static complement(probability)`
- `static independent(probabilityA, probabilityB)`
- `static mutuallyExclusive(probabilityA, probabilityB)`
- `static union(probabilityA, probabilityB, intersection)`
- `static conditional(intersection, probabilityB)`
- `static bayes(probabilityBGivenA, probabilityA, probabilityB)`
- `static factorial(n)`
- `static permutation(n, r)`
- `static combination(n, r)`
- `static binomial(n, k, probability)`
- `static binomialAtMost(n, k, probability)`
- `static binomialAtLeast(n, k, probability)`
- `static expectedValue(values, probabilities)`
- `static variance(values, probabilities)`
- `static standardDeviation(values, probabilities)`
- `static uniform(value, minimum, maximum)`
- `static uniformCdf(value, minimum, maximum)`
- `static normal(value, mean, standardDeviation)`
- `static normalCdf(value, mean, standardDeviation)`
- `static bernoulli(value, probability)`
- `static geometric(k, probability)`
- `static poisson(k, lambda)`
- `static hypergeometric(population, successes, sample, observed)`
- `static standardError(standardDeviation, sampleSize)`
- `static probabilityToOdds(probability)`
- `static oddsToProbability(odds)`
- `static toPercent(probability)`
- `static fromPercent(percent)`


## Module: `random`
---

### Class: `NativeRandom`
**Methods:**
- `static create()`
- `static createWithSeed(seed)`
- `static nextDouble(nativeRnd)`
- `static nextInt(nativeRnd, max)`
- `static nextBool(nativeRnd)`


### Class: `Random`
**Properties:**
- `_native`

**Methods:**
- `init()`
- `seed(value)`
- `next()`
- `boolean()`
- `double(minimum, maximum)`
- `int(minimum, maximum)`
- `choice(list)`
- `index(length)`
- `shuffle(list)`
- `take(list)`
- `sign()`
- `chance(percent)`
- `hexColor()`
- `static hex(value)`


## Module: `regex`
---

### Class: `RegExp`
**Properties:**
- `_nativeData`

**Methods:**
- `init(pattern)`
- `compile(pattern)`
- `hasMatch(string)`
- `stringMatch(string)`
- `replaceAll(string, replacement)`


## Module: `socket`
---

### Class: `Socket`
**Methods:**
- `static connect(host, port)`
- `write(data)`
- `writeAsBytes(buffer)`
- `read()`
- `readAsBytes()`
- `close()`


### Class: `ServerSocket`
**Methods:**
- `static bind(host, port)`
- `accept()`
- `close()`


## Module: `statistics`
---

### Class: `Statistics`
**Methods:**
- `static count(values)`
- `static sum(values)`
- `static min(values)`
- `static max(values)`
- `static range(values)`
- `static mean(values)`
- `static median(values)`
- `static mode(values)`
- `static variance(values)`
- `static sampleVariance(values)`
- `static standardDeviation(values)`
- `static sampleStandardDeviation(values)`
- `static percentile(values, percent)`
- `static quartile1(values)`
- `static quartile2(values)`
- `static quartile3(values)`
- `static interquartileRange(values)`
- `static zScore(value, values)`
- `static covariance(x, y)`
- `static sampleCovariance(x, y)`
- `static correlation(x, y)`
- `static meanAbsoluteDeviation(values)`
- `static rootMeanSquare(values)`
- `static weightedMean(values, weights)`
- `static sort(values)`
- `static frequency(values, target)`
- `static normalize(value, minimum, maximum)`
- `static skewness(values)`
- `static summary(values)`


## Module: `udpsocket`
---

### Class: `UDPSocket`
**Methods:**
- `static bind(host, port)`
- `send(data, host, port)`
- `sendBytes(buffer, host, port)`
- `receive()`
- `receiveBytes()`
- `close()`


## Module: `url`
---

### Class: `URL`
**Properties:**
- `scheme`
- `host`
- `port`
- `path`
- `query`
- `fragment`
- `userInfo`
- `authority`

**Methods:**
- `static parse(urlString)`


## Module: `vml`
---

### Class: `VML`
**Methods:**
- `static parse(source)`
- `static parseFile(path)`
- `static toHTML(source)`


### Class: `VmlDocument`
**Methods:**
- `toHTML()`
- `nodes()`


### Class: `VmlElement`
**Methods:**
- `querySelector(tag)`
- `querySelectorAll(tag)`
- `findId(id)`
- `findGroup(group)`
- `getAttribute(name)`
- `setAttr(name, value)`
- `removeAttr(name)`
- `append(node)`
- `remove(node)`
- `setText(text)`
- `toHTML()`
- `tagName()`
- `attributes()`
- `children()`
- `parent()`
- `next()`
- `prev()`


### Class: `VmlText`
**Methods:**
- `text()`
- `setText(text)`
- `toHTML()`
- `parent()`
- `next()`
- `prev()`


## Module: `websocket`
---

### Class: `WebSocketClient`
**Methods:**
- `static connect(url)`
- `send(data)`
- `receive()`
- `close()`


### Class: `WebSocketServer`
**Methods:**
- `static bind(host, port)`
- `accept()`
- `close()`



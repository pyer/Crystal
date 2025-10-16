# Logger

Tiny console logger for Crystal

## Installation

```
cp src/logger.cr /usr/share/crystal/src/
```

## Usage

### Example of default level

```crystal
require "logger"

log = Logger.new

log.trace "trace"
log.debug "debug"
log.info  "info"
```

prints

```
[INFO ] info
```

### Example of Debug level

```crystal
require "logger"

log = Logger.new(Logger::Level::Debug)

log.trace "trace"
log.debug "debug"
log.info  "info"
```

prints

```
[DEBUG] debug
[INFO ] info
```

## Logger levels

* Logger::Level::Trace
* Logger::Level::Debug
* Logger::Level::Info
* Logger::Level::Warn
* Logger::Level::Error
* Logger::Level::None



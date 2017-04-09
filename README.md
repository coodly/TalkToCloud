# TalkToCloud

Swift library for server-to-server CloudKit communication. Uses container based methods, allowing access to multiple containers in same project.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Installing

- Add `TalkToCloud` to your `Package.swift`

```swift
import PackageDescription

let package = Package(
	dependencies: [
		.Package(url: "https://github.com/coodly/TalkToCloud.git", Version(0, 5, 1))
	]
)

```

## Quick run

Save your credentials in *Config* folder using following naming:

    .
    ├── Config
    │   ├── com.coodly.moviez-development.key  # Key ID from Dashboard -> API Access -> Server-to-Server keys  
    │   ├── com.coodly.moviez-development.pen  # Private key

Create task conforming to *Command* protocol.

Indicate used container by using protocols *ProductionConsumer* and/or *DevelopmentConsumer*.

```swift
import TalkToCloud

class Loader: Command, DevelopmentConsumer, ProductionConsumer {
    var developmentContainer: CloudContainer!
    var productionContainer: CloudContainer!
}
```


As alternative you can use *ContainerConsumer* and used container will be figured out at runtime.

```swift
import TalkToCloud

class Loader: Command, ContainerConsumer {
    var container: CloudContainer!
}
```

In main.swift, create a command executor.

```swift
let commander = Commander<Loader>(containerId: "com.coodly.moviez", arguments: CommandLine.arguments)
commander.run()
```

When using *ContainerConsumer*, use **--development** or **--production** to indicate which environment container should be given to command.

## License

This project is licensed under the Apache 2 License - see the [LICENSE](LICENSE) file for details

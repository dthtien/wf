# DWF
Distributed workflow runner following [Gush](https://github.com/chaps-io/gush) interface using [Sidekiq](https://github.com/mperham/sidekiq) and [Redis](https://redis.io/). This project is for researching DSL purpose

# Installation
## 1. Add `dwf` to Gemfile
```ruby
gem 'dwf', '~> 0.1.12'
```
## 2. Execute flow example
### Declare jobs

```ruby
require 'dwf'

class FirstItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running"
    puts "#{self.class.name}: finish"
  end
end

class SecondItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running"
    output('Send to ThirdItem')
    puts "#{self.class.name} finish"
  end
end

class ThirdItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running"
    puts "#{self.class.name}: finish"
  end
end

class FourthItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running"
    puts "payloads from incoming: #{payloads.inspect}"
    puts "#{self.class.name}: finish"
  end
end

FifthItem = Class.new(FirstItem)
```

### Declare flow
```ruby
require 'dwf'

class TestWf < Dwf::Workflow
  def configure
    run FirstItem
    run SecondItem, after: FirstItem
    run ThirdItem, after: FirstItem
    run FourthItem, after: [ThirdItem, SecondItem]
    run FifthItem, after: FourthItem
  end
end
```
### Start background worker process
```
bundle exec sidekiq -q dwf
```

### Execute flow
```ruby
wf = TestWf.create
wf.callback_type = Dwf::Workflow::SK_BATCH
wf.start!
```

#### Note
`dwf` supports 2 callback types `Dwf::Workflow::BUILD_IN` and `Dwf::Workflow::SK_BATCH`
- `Dwf::Workflow::BUILD_IN` is a build-in callback
- `Dwf::Workflow::SK_BATCH` is [sidekiq batch](https://github.com/mperham/sidekiq/wiki/Batches) callback which required [`sidekiq-pro`](https://sidekiq.org/products/pro.html)

By default `dwf` will use `Dwf::Workflow::BUILD_IN` callback.

### Output
```
FirstItem: running
FirstItem: finish
SecondItem: running
SecondItem finish
ThirdItem: running
ThirdItem: finish
FourthItem: running
FourthItem: finish
FifthItem: running
FifthItem: finish
```

# Config redis and default queue
`dwf` uses redis as the key value stograge through [redis-rb](https://github.com/redis/redis-rb), So you can pass redis configuration by `redis_opts`
```ruby
Dwf.config do |config|
  SENTINELS = [
    { host: "127.0.0.1", port: 26380 },
    { host: "127.0.0.1", port: 26381 }
  ]
  config.redis_opts = { host: 'mymaster', sentinels: SENTINELS, role: :master }
  config.namespace = 'dwf'
end
```
# Advanced features
## Pipelining
You can pass jobs result to next nodes

```ruby
class SendOutput < Dwf::Item
  def perform
    output('it works')
  end
end

```

`output` method used to output data from the job to add outgoing jobs

```ruby
class ReceiveOutput < Dwf::Item
  def perform
    message = payloads.first[:output] # it works
  end
end
```

`payloads` is an array that containing outputs from incoming jobs

```ruby
[
  {
    id: "SendOutput|1849a3f9-5fce-401e-a73a-91fc1048356",
    class: "SendOutput",
    output: 'it works'
  }
]
```
## Sub workflow
There might be a case when you want to reuse a workflow in another workflow

As an example, let's write a workflow which contain another workflow, expected that the SubWorkflow workflow execute after `SecondItem` and the `ThirdItem` execute after `SubWorkflow`

### Setup
```ruby
class FirstItem < Dwf::Item
  def perform
    puts "Main flow: #{self.class.name} running"
    puts "Main flow: #{self.class.name} finish"
  end
end

SecondItem = Class.new(FirstItem)
ThirtItem = Class.new(FirstItem)

class FirstSubItem < Dwf::Item
  def perform
    puts "Sub flow: #{self.class.name} running"
    puts "Sub flow: #{self.class.name} finish"
  end
end

SecondSubItem = Class.new(FirstSubItem)

class SubWorkflow < Dwf::Workflow
  def configure
    run FirstSubItem
    run SecondSubItem, after: FirstSubItem
  end
end


class TestWf < Dwf::Workflow
  def configure
    run FirstItem
    run SecondItem, after: FirstItem
    run SubWorkflow, after: SecondItem
    run ThirtItem, after: SubWorkflow
  end
end

wf = TestWf.create
wf.start!
```

### Result
```
Main flow: FirstItem running
Main flow: FirstItem finish
Main flow: SecondItem running
Main flow: SecondItem finish
Sub flow: FirstSubItem running
Sub flow: FirstSubItem finish
Sub flow: SecondSubItem running
Sub flow: SecondSubItem finish
Main flow: ThirtItem running
Main flow: ThirtItem finish
```

## Dynamic workflows
There might be a case when you have to contruct the workflow dynamically depend on the input
As an example, let's write a workflow which puts from 1 to 100 into the terminal parallelly . Additionally after finish all job, it will puts the finshed word into the terminal
```ruby
class FirstMainItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running #{params}"
  end
end

SecondMainItem = Class.new(FirstMainItem)

class TestWf < Dwf::Workflow
  def configure
    items = (1..100).to_a.map do |number|
      run FirstMainItem, params: number
    end
    run SecondMainItem, after: items, params: "finished"
  end
end

```
We can achieve that because run method returns the id of the created job, which we can use for chaining dependencies.
Now, when we create the workflow like this:
```ruby
wf = TestWf.create
# wf.callback_type = Dwf::Workflow::SK_BATCH
wf.start!
```

# Todo
- [x] Make it work
- [x] Support pass params
- [x] Support with build-in callback
- [x] Add github workflow
- [x] Redis configurable
- [x] Pipelining
- [X] Test
- [x] Sub workflow
- [ ] Support [Resque](https://github.com/resque/resque)
- [ ] Key value store plugable
  - [ ] research https://github.com/moneta-rb/moneta

# References
- https://github.com/chaps-io/gush
- https://github.com/mperham/sidekiq

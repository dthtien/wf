# DSL playground
[Gush](https://github.com/chaps-io/gush) cloned without [ActiveJob](https://guides.rubyonrails.org/active_job_basics.html) but requried [Sidekiq](https://github.com/mperham/sidekiq). This project is for researching DSL purpose

# Installation
## 1. Add `dwf` to Gemfile
```ruby
gem 'dwf', '~> 0.1.9'
```
## 2. Execute flow
### Declare jobs

```ruby
require 'dwf'

class A < Dwf::Item
  def perform
    puts "#{self.class.name} Working"
    sleep 2
    puts params
    puts "#{self.class.name} Finished"
  end
end
```

### Declare flow
```ruby
require 'dwf'

class TestWf < Dwf::Workflow
  def configure
    run A
    run B, after: A
    run C, after: A
    run E, after: [B, C], params: 'E say hello'
    run D, after: [E], params: 'D say hello'
    run F, params: 'F say hello'
  end
end
```


### Execute flow
```ruby
wf = TestWf.create(callback_type: Dwf::Workflow::SK_BATCH)
wf.start!
```

#### Note
`dwf` supports 2 callback types `Dwf::Workflow::BUILD_IN` and `Dwf::Workflow::SK_BATCH`
- `Dwf::Workflow::BUILD_IN` is a build-in callback
- `Dwf::Workflow::SK_BATCH` is [sidekiq batch](https://github.com/mperham/sidekiq/wiki/Batches) callback which required [`sidekiq-pro`](https://sidekiq.org/products/pro.html)

By default `dwf` will use `Dwf::Workflow::BUILD_IN` callback.

### Output
```
A Working
F Working
A Finished
F say hello
F Finished
C Working
B Working
C Finished
B Finished
E Working
E say hello
E Finished
D Working
D say hello
D Finished
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

# Pinelining
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

# Todo
- [x] Make it work
- [x] Support pass params
- [x] Support with build-in callback
- [x] Add github workflow
- [x] Redis configurable
- [x] Pinelining
- [X] Test
- [ ] Consistent item name
- [ ] Support [Resque](https://github.com/resque/resque)
- [ ] Key value store plugable
  - [ ] research https://github.com/moneta-rb/moneta

# References
- https://github.com/chaps-io/gush
- https://github.com/mperham/sidekiq

# DSL playground
[Gush](https://github.com/chaps-io/gush) cloned without [ActiveJob](https://guides.rubyonrails.org/active_job_basics.html) but requried [Sidekiq](https://github.com/mperham/sidekiq). This project is for researching DSL purpose

# Installation
## 1. Add `dwf` to Gemfile
```ruby
gem 'dwf', '~> 0.1.6'
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
```ruby
Dwf.config do |config|
  SENTINELS = [
    { host: "127.0.0.1", port: 26380 },
    { host: "127.0.0.1", port: 26381 }
  ]
  config.opts = { host: 'mymaster', sentinels: SENTINELS, role: :master }
  config.namespace = 'dwf'
end
```


# Todo
- [x] Make it work
- [x] Support pass params
- [x] Support with build-in callback
- [x] Add github workflow
- [x] Redis configurable
- [ ] [WIP] Test
- [ ] Transfer output through each node
- [ ] Support [Resque](https://github.com/resque/resque)

# References
- https://github.com/chaps-io/gush
- https://github.com/mperham/sidekiq

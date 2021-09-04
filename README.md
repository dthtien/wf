# DSL playground
[Gush](https://github.com/chaps-io/gush) cloned without [ActiveJob](https://guides.rubyonrails.org/active_job_basics.html) but requried [Sidekiq](https://github.com/mperham/sidekiq). This project is for researching DSL purpose

# Installation
```ruby
gem 'dwf', '~> 0.1.2'
```
# Execute flow
## Declare jobs

```ruby
require 'dwf'

class A < Dwf::Item
  def perform
    puts "#{self.class.name} Working"
    sleep 2
    puts "#{self.class.name} Finished"
  end
end

class E < A; end
class B < A; end
class C < E; end
class D < E; end
```

## Declare flow
```ruby
require 'dwf'

class TestWf < Dwf::Workflow
  def configure
    run A
    run B, after: A
    run C, after: A
    run E, after: [B, C]
    run D, after: [E]
  end
end

```

### Execute flow
```ruby
wf = TestWf.create
wf.start!
```

### Output
```
A Working
A Finished
B Working
C Working
B Finished
C Finished
E Working
E Finished
D Working
D Finished
```

# Todo
- [x] Make it work
- [ ] Support with build-in callback
- [ ] Test
- [ ] Support pass params
- [ ] Add github workflow

# References
- https://github.com/chaps-io/gush
- https://github.com/mperham/sidekiq

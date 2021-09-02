class Workflow
  attr_reader :id

  def initialize
    @dependencies = []
    @id = id
  end

  def configure
    run A
    run B, after: A
    run C, after: A
    run E, after: A
    run D, after: [B, C, E]
  end

  def run(klass, options); end
end

# ->

class Performer
  def success(_, _)
    puts "Finished!"
  end

  def start
    batch = Sidekiq::Batch.new
    batch.on(:success, "Performer#success")
    batch.jobs do
      step1 = Sidekiq::Batch.new
      step1.on(:success, "Performer#step2", a: 1)
      step1.jobs do
        A.perform_async
      end
    end
  end

  def step2(status, _)
    puts "Test execute step2"
    overall = Sidekiq::Batch.new(status.parent_bid)
    overall.jobs do
      step2 = Sidekiq::Batch.new
      step2.on(:success, 'Performer#step3', b: 2)
      step2.jobs do
        B.perform_async
        C.perform_async
        E.perform_async
      end
    end
  end

  def step3(status, _)
    puts "Test execute step3"
    overall = Sidekiq::Batch.new(status.parent_bid)
    overall.jobs do
      D.perform_async
    end
  end
end


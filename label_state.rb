require 'time'

class LabelState
  attr_accessor :time, :label_index

  def initialize (*args)
    if (args.size == 0)
      init_zero
    elsif (args.size == 1)
      init_one(args[0])
    elsif (args.size == 2)
      init_two(args[0], args[1])
    else
      puts "error: too many args"
      return nil
    end
  end

  def init_zero
    @time = Time.now
    @label_index = 0
  end

  def init_one(json_string)
    from_json(json_string)
  end

  def init_two(label_index, time)
    @time = time
    @label_index = label_index
  end

  def to_json
    "{ \"#{@label_index}\" : \"#{@time}\" }"
  end

  def from_json(json_string)
    m = /\{ "(.*)" : "(.*)" \}/.match(json_string)
    if (m.nil?)
      @time = nil
      @label_index = "error: failed to load from json"
    else
      @label_index = m[1]
      @time = m[2]
    end
  end
end
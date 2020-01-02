class User
  getter channel : Channel(String)
  private getter name : String, email : String

  def initialize(@name="anonymous", @email="anon@none.ch")
    @channel = Channel(String).new
    listen_for_messages
  end

  def send_message(receiver : User, text : String)
    message = text.to_s
    post_to_self(receiver.to_s, message)  # can't send to own channel so print directly
    return if receiver == self            # abort to prevent a channel loop

    # switch between async & real-time messaging (& use both) to see delivery differences
    # receiver.channel.send("REAL-TIME SEND: #{message}")
    spawn receiver.channel.send("ASYNC SEND: #{message}")
  end

  private def post_to_self(receipient_string : String, message : String)
    post_message("REAL-TIME SELF-POST: #{message}")
  end

  private def post_message(message : String)
    puts message.to_s
    self
  end

  private def listen_for_messages
    spawn do
      loop do
        message = channel.receive?
        break     if message.nil?   # Channel is closed - skip
        post_message("VIA CHANNEL: #{message}")
      end
    end
  end

end

module DirectChannels
  VERSION = "0.1.0"

  # two named users for light testing
  user_1 = User.new(name: "first",  email: "first@noise.ch")
  user_2 = User.new(name: "second", email: "second@noise.ch")

  # direct sends via channel
  puts "REAL-TIME - START"
  spawn user_1.channel.send("ASYNC channel send!")

  puts "\nREAL-TIME Step - 1"
  user_1.channel.send("REAL-TIME to channel send!")

  # direct send without channel
  puts "\nREAL-TIME Step - 2"
  user_2.post_message("REAL-TIME - sent directly")

  # send with channels within user class
  puts "\nREAL-TIME Step - 3"
  user_1.send_message(receiver: user_2, text: "To user_1")

  puts "\nREAL-TIME Step - 4"
  user_2.send_message(receiver: user_1, text: "To user_2: Always arrives first")

  puts "\nREAL-TIME Step - 5"
  user_2.send_message(receiver: user_1, text: "To user_2: Always arrives second")

  puts "\nREAL-TIME Step - 6"
  user_1.send_message(receiver: user_1, text: "No Loop when sent to self")

  puts "\nREAL-TIME - DONE"
  puts

  # Fiber.yield  # not needed since all spawns are called on methods
  # let fibers finish - what's the best way to wait for async messages finish?
  sleep 1
end

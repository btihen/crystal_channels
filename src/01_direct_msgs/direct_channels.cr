# NOTE: lots of print statements to help understand the timing

class User
  getter( name : String, email : String, channel : Channel(String) )

  def initialize(@name="anonymous", @email="anon@none.ch")
    @channel = Channel(String).new
    # puts "REAL-TIME: CREATED USER: #{to_s}"
    listen_for_messages
  end

  def send_message(receiver : User, text : String, topic = "")
    message = formatted_message(receiver: receiver, text: text, topic: topic)
    post_to_self(receiver.to_s, message)  # can't send to own channel so print directly
    return self  if receiver == self      # abort to prevent a channel loop

    # try switching between async or real-time messaging
    # also interesting is to use both and see how it affects concurrency
    # receiver.channel.send("REAL-TIME via CHANNEL:\n#{message}")
    spawn receiver.channel.send("ASYNC via CHANNEL:\n#{message}")
    self
  end

  def post_to_self(receipient_string : String, message : String)
    puts "^" * 40
    puts "REAL-TIME: self-post to: #{receipient_string}"
    post_message(message)
    puts "^" * 40
    self
  end

  def post_message(message : String)
    puts message.to_s
    self
  end

  def to_s
    "#{name} <#{email}>"
  end

  def listen_for_messages
    spawn do
      loop do
        message = channel.receive?
        break     if message.nil?   # Channel is closed - skip

        puts "*" * 50
        puts "Channel Post"
        post_message(message)
        puts "*" * 50
      end
    end
  end

  def formatted_message(text, receiver, sender=self, topic="")
    output = [] of String
    output << "-" * 30
    output << "To: #{receiver.to_s}"
    output << "From: #{sender.to_s}"
    output << "Topic: #{topic}"      unless topic == ""
    output << "----"
    output << text
    output << "-" * 30
    output.join("\n")
  end

end

module DirectChannels
  VERSION = "0.1.0"

  # two named users for light testing
  user_1 = User.new(name: "first",  email: "first@noise.ch")
  user_2 = User.new(name: "second", email: "second@noise.ch")

  # sent to user1 aysnc via a channel
  puts "REAL-TIME - START"
  spawn user_1.channel.send("ASYNC channel send!")

  puts "\nREAL-TIME Step - 1"
  user_1.channel.send("REAL-TIME to channel send!")

  # can send directly - without channels
  puts "\nREAL-TIME Step - 2"
  user_2.post_message("REAL-TIME - sent directly")

  # use the channels between users
  # NOTICE: all self-post happen immediately as they don't use channels or fibers,
  # The messages over channels happen once Fiber.yield happens, the oder
  puts "\nREAL-TIME Step - 3"
  user_1.send_message(receiver: user_2, text: "Hi user 1")

  puts "\nREAL-TIME Step - 4"
  user_2.send_message(receiver: user_1, topic: "1 Enjoy Channels", text: "Over channels this always arrives first")

  puts "\nREAL-TIME Step - 5"
  user_2.send_message(receiver: user_1, topic: "2 Understand Channels", text: "Over channels this always arrives second")

  puts "\nREAL-TIME Step - 6"
  user_1.send_message(receiver: user_1, text: "No Loop when sent to me")

  puts "\nREAL-TIME - DONE"
  puts

  # Fiber.yield  # not needed since all spawns are called on methods

  # let fibers finish
  sleep 1        # what's the best way to wait for all async messages to be delivered?
end

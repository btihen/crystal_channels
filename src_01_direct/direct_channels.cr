class Message
  getter sender : User, topic : String, receiver : User
  private getter text : String

  def initialize(@sender, @text, @receiver, @topic="")
    @text = text.strip
    @topic = topic.strip
  end

  def topic=(topic : String)
    @topic = topic.strip
  end

  def to_s
    output = [] of String
    output << "-" * 30
    output << "From: #{sender.to_s}"
    output << "To: #{receiver.to_s}"
    output << "Topic: #{topic}"      unless topic == ""
    output << text
    output << "-" * 30
    output.join("\n")
  end
end


##########
class User
  getter( name : String, email : String, channel : Channel(Message) )

  def initialize(@name="anonymous", @email="anon@none.ch")
    @channel = Channel(Message).new
    # puts "CREATED USER: #{to_s}"
    listen_for_messages
  end

  def send_message(receiver : User, text : String, topic = "")
    message = Message.new(sender: self, receiver: receiver, text: text, topic: topic)
    post_to_self(receiver.to_s, message)  # can't send to own channel so print directly
    return self  if receiver == self      # abort to prevent a channel loop

    receiver.channel.send(message)
    # spawn receiver.channel.send(message)
    self
  end

  def post_to_self(receipient_string : String, message : Message)
    puts "^" * 40
    puts "Self post to: #{receipient_string}"
    post_message(message)
    puts "^" * 40
    self
  end

  def post_message(message : Message)
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

end

module DirectChannels
  VERSION = "0.1.0"

  # two named users for light testing
  user_1 = User.new(name: "first",  email: "first@noise.ch")
  user_2 = User.new(name: "second", email: "second@noise.ch")

  # # test that users can send direct messages to each other's channels directly
  user_1.channel.send( Message.new(sender: user_2, receiver: user_1, text: "Hi there!") )
  # user_2.channel.send( Message.new(sender: user_1, receiver: user_2, text: "Howdy!") )

  puts "#" * 60

  # # use the user api
  user_1.send_message(receiver: user_2, text: "Hi API #2")
  # user_1.send_message(receiver: user_1, text: "No Loop")
  # user_2.send_message(receiver: user_1, text: "Enjoy channels")

  # let fibers / channels finish
  Fiber.yield
end

class Message
  getter sender : User, topic : String, receiver : User
  private getter text : String

  def initialize(@sender, @text, @receiver=NoUser.new, @topic="")
    @text = text.strip
    @topic = topic.strip
  end

  # DONT MUTATE AFTER SENDING!
  def topic=(topic : String)
    @topic = topic.strip
  end

  def to_s
    output = [] of String
    output << "-" * 30
    output << "From: #{sender.to_s}"
    output << "To: #{receiver.to_s}" unless receiver.name == "anonymous"
    output << "Topic: #{topic}"      unless topic == "" || topic == topic.to_s
    output << "Mesg: #{text}"
    output << "-" * 30
    output.join("\n")
  end
end

###############
module Listener
  def listen_for_messages
    spawn do
      loop do
        message = channel.receive?
        break  if message.nil?      # Channel is closed - skip to others

        puts "*" * 50
        puts "Channel Post in #{self.to_s}"
        post_message(message)
        puts "*" * 50
      end
    end
  end
end

##########
class User
  include Listener

  getter( name : String,
          email : String,
          channel : Channel(Message)
        )

  def initialize(@name="anonymous", @email="anon@none.ch")
    @channel = Channel(Message).new
    puts "CREATED USER: #{to_s}"
    listen_for_messages
  end

  def send_message(room : Room, text : String)
    message = Message.new(sender: self, text: text)
    spawn room.channel.send(message)
    self
  end

  def send_message(room : Room, receiver : User, text : String, topic = "")
    message = Message.new(sender: self, receiver: receiver, text: text, topic: topic)
    spawn room.channel.send(message)
    self
  end

  def send_message(receiver : User, text : String, topic = "")
    message = Message.new(sender: self, receiver: receiver, text: text, topic: topic)
    post_to_self(receiver.to_s, message)  # without using a channel
    return self  if receiver == self  # prevent a channel loop recursively to self

    spawn receiver.channel.send(message)
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
end

class NoUser < User
  def initialize()
    @name    = "anonymous"
    @email   = "anon@none.ch"
    @channel = Channel(Message).new
    # puts "CREATED ANON USER: #{to_s}"
    # listen_for_messages
  end

  # discard posted messages
  def post_message(message : Message)
  end
end


##########
class Room
  include Listener

  getter channel : Channel(Message)
  private getter( topic : String, users = {} of String => User )

  def initialize(@topic="default")
    @users = {} of String => User
    @channel = Channel(Message).new
    puts "CREATED room #{@topic}"
    listen_for_messages
  end

  def join(user : User)
    return self if users.has_key? user.email

    @users[user.email] = user
    puts "#{user.name} has JOINED room #{topic}"
    self
  end

  def leave(user : User)
    return self unless users.has_key? user.email

    @users.delete(user.email)
    puts "#{user.name} has LEFT room #{topic}"
    self
  end

  def to_s
    topic
  end

  def post_message(message : Message)
    sender = message.sender
    puts "Rejected Message" unless users.has_key?(sender.email)
    return self             unless users.has_key?(sender.email)

    message.topic = "#{topic.upcase} #{message.topic}"
    receiver = message.receiver
    case receiver.name
    when "anonymous"
      puts "sending broadcast in #{to_s}"
      spawn send_broadcast(message)
    else
      puts "sending chat direct to: #{receiver.to_s}"
      spawn send_message(receiver, message) if users.has_key?(receiver.email)
    end
    # with spawn on a method - `Fiber.yield` not needed
    # Fiber.yield
    self
  end

  private def send_broadcast(full_message : Message)
    users.each_value do |receiver|
      send_message(receiver, full_message)
    end
    self
  end

  private def send_message(receiver : User, full_message : Message)
    receiver.channel.send(full_message)
    self
  end
end

module ChatChannels
  VERSION = "0.1.0"


  # two named users for light testing
  user_1 = User.new(name: "first",  email: "first@noise.ch")
  user_2 = User.new(name: "second", email: "second@noise.ch")

  # # test that users can send direct messages to each other's channels directly
  # user_1.channel.send( Message.new(sender: user_2, receiver: user_1, text: "Hi there!") )
  # user_2.channel.send( Message.new(sender: user_1, receiver: user_2, text: "Howdy!") )
  #
  # puts "#" * 60

  # # use the user api
  # user_1.send_message(receiver: user_2, text: "Hi API #2")
  # user_1.send_message(receiver: user_1, text: "No Loop")
  # user_2.send_message(receiver: user_1, text: "Enjoy channels")

  # create a chat room
  chat = Room.new(topic: "noise")

  # # first two joing chat
  chat.join(user_1)
  chat.join(user_2)
  # chat.join(user_2)  # should have no effect
  #
  # puts "%" * 55
  # # light messaging tests in message board
  # user_1.send_message(room: chat, text: "Cool Stuff")
  # # user_2.send_message(room: chat, text: "Enjoy These", topic: "Channels")
  #
  #
  # puts "%" * 55
  # Fiber.yield   # stop until messages delivered
  #
  # puts "%" * 55
  #
  # # leave chat
  # chat.leave(user_1)
  # user_1.send_message(room: chat, text: "Not Seen - already left group")
  # Fiber.yield
  # chat.leave(user_2)
  # chat.leave(user_2)  # should have no effect

  puts "#" * 60
  #
  # stress testing
  users  = [] of User
  100000.times do |i|
    user_i = User.new(name: "user_#{i}", email: "user_#{i}@noise.ch")
    chat.join(user_i)
  end

  user_1.send_message(room: chat, receiver: user_2, text: "Direct two you")
  user_1.send_message(room: chat, text: "Cool Stuff")
  # have each user send a message to the group
  # users.each do |user|
  #   user.send_message(room: chat, text: "#{user.to_s} to all")
  # end

  # let spawned fibers / channels run
  Fiber.yield
  #
  sleep 3  # let all the channels finish before disconnecting abruptly

  # users.each do |user|
  #   # chat.leave(user)
  #   spawn chat.leave(user)
  # end
  # Fiber.yield

end

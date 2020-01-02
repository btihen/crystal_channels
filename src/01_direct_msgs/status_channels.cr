class User
  getter channel : Channel(String)
  private getter name : String, email : String, status : Channel(Nil)

  def initialize(@name, @email, @status)
    @channel = Channel(String).new(1)
    listen_for_messages
  end

  def send_message(message : String, receiver : User = self)
    if message == "close" && receiver == self
      # works when all messages are queued immediately i.e. no: spawn channel.send("message")
      puts "CLOSING: #{to_s}"
      channel.close
      status.send(nil)
    elsif receiver == self           # avoid infinite channel loop with self
      post_message "SELF: #{message}"
    elsif !receiver.channel.closed?  # avoid some runtime errors - don't send if channel already closed
      receiver.channel.send(message)
      # async messaging can lead to errors since if channel closes BEFORE DELIVERY
      # spawn receiver.channel.send(message)
    else
      puts "NO DELIVERY: To: #{receiver.to_s} not receiving -- Message: '#{message}'"
    end
  end

  def to_s
    "#{name} <#{email}>"
  end

  private def post_message(message)
    puts "To: #{to_s} -- #{message}"
  end

  private def listen_for_messages
    spawn do
      loop do
        message = channel.receive?
        break     if message.nil?  # Channel is emppost_message(message)

        post_message("CHANNEL: #{message}")
      end
    end
  end
end


# create users
status = Channel(Nil).new
user_1 = User.new(name: "first",  email: "first@example.ch", status: status)
user_2 = User.new(name: "second", email: "second@example.ch", status: status)

# and user list
users = [] of User
users << user_1
users << user_2

puts "REAL-TIME - START"
spawn user_1.send_message("ASYNC sent 1st", receiver: user_2)
user_1.send_message("REAL-TIME sent 2nd", receiver: user_2)
spawn user_1.send_message("ASYNC sent 3th", receiver: user_2)
spawn user_2.send_message("ASYNC sent 4th", receiver: user_1)
user_2.send_message("REAL-TIME sent 5th", receiver: user_1)
user_1.send_message("REAL-TIME sent 6th", receiver: user_1)

# close channels - async to allow messages to flush
spawn user_1.send_message("close")
spawn user_2.send_message("close")
puts "REAL-TIME - DONE"

puts "STATUS Channels - Testing"
user_count = users.size
user_count.times { status.receive }
puts "STATUS Channels - DONE"
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"

user_1.send_message("No Error - not sent", receiver: user_2)  # protected from run-time error
# this creates a runtime error if you send to a closed channel
# user_1.channel.send("RUNTIME Error")

# another way to wait for all channels to close
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"
loop do
  break if users.all?{ |u| u.channel.closed? }
  Fiber.yield  # give fibers a chance to execute
end
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"


users  = [] of User
status = Channel(Nil).new
100.times do |i|
  user = User.new(name: "user_#{i}",  email: "user_#{i}@example.ch", status: status)
  users << user
end

users.each do |sender|
  users.each do |receiver|
    sender.send_message("From: #{sender.to_s} - with channel", receiver: receiver)
    # async messaging can lead to errors since if channel closes BEFORE DELIVERY
    # spawn sender.send_message("From: #{sender.to_s} - with channel", receiver: receiver)
  end
end

users.each do |sender|
  # sender.send_message("close")
  spawn sender.send_message("close")
end

puts "STATUS Channels - Testing"
user_count = users.size
user_count.times { status.receive }
puts "STATUS Channels - DONE"
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"

# users.each do |sender|
#   spawn sender.channel.close
# end

# # wait for all channels to close
# puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"
# loop do
#   break if users.all?{ |u| u.channel.closed? }
#   Fiber.yield  # give fibers a chance to execute
# end
# puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"

class User
  getter channel : Channel(String)
  private getter name : String, email : String

  def initialize(@name, @email)
    @channel = Channel(String).new
    listen_for_messages
  end

  def send_message(message : String, receiver : User = self)
    if message == "close" && receiver == self
      puts "Channel closing for: #{to_s}"
      channel.close
    elsif receiver == self           # avoid infinite channel loop with self
      post_message("SELF-POST: #{message}")
    elsif !receiver.channel.closed?  # avoid runtime error (if possible)
      receiver.channel.send(message)
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
        break  if message.nil?      # Channel is empty - skip

        post_message("CHANNEL-POST: #{message}")
      end
    end
  end
end

# create users
user_1 = User.new(name: "first",  email: "first@example.ch")
user_2 = User.new(name: "second", email: "second@example.ch")
# and user list
users = [] of User
users << user_1
users << user_2

puts "REAL-TIME - START"
spawn user_1.send_message("ASYNC sent 1st", receiver: user_1)
user_1.send_message("REAL-TIME sent 2nd", receiver: user_1)
user_1.send_message("REAL-TIME sent 3th", receiver: user_2)
user_2.send_message("REAL-TIME sent 4th", receiver: user_1)
spawn user_2.send_message("ASYNC sent 5th", receiver: user_1)
user_1.send_message("REAL-TIME sent 6th", receiver: user_2)

# close channels - async to allow messages to flush
spawn user_1.send_message("close")
spawn user_2.send_message("close")
puts "REAL-TIME - DONE"

# wait for all channels to close
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"
loop do
  break if users.all?{ |u| u.channel.closed? }
  Fiber.yield  # give fibers a chance to execute
  # its interesting to see how long to close by using puts instead of Fiber.yield
  # puts users.all?{ |u| u.channel.closed? }
end
puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"

user_1.send_message("No Error - not sent", receiver: user_2)  # protected from run-time error
# user_1.channel.send("RUNTIME Error")  # runtime error if you send to a closed channel

# REAL-TIME - START
# To: first <first@example.ch> -- SELF-POST: REAL-TIME sent 2nd
# To: second <second@example.ch> -- CHANNEL-POST: REAL-TIME sent 3th
# To: first <first@example.ch> -- SELF-POST: ASYNC sent 1st
# REAL-TIME - DONE
# ALL CLEINTS CLOSED? false
# To: first <first@example.ch> -- CHANNEL-POST: REAL-TIME sent 4th
# To: second <second@example.ch> -- CHANNEL-POST: REAL-TIME sent 6th
# Channel closing for: first <first@example.ch>
# Channel closing for: second <second@example.ch>
# To: first <first@example.ch> -- CHANNEL-POST: ASYNC sent 5th
# ALL CLEINTS CLOSED? true
# NO DELIVERY: To: second <second@example.ch> not receiving -- Message: 'No Error - not sent'

users = []
100.times do |i|
  user = User.new(name: "user_#{i}",  email: "user_#{i}@example.ch")
  users << user
end

users.each do |sender|
  users.each do |receiver|
    sender.send_message("From: #{sender.to_s} - with channel", receiver: receiver)
    # async messaging in this case leads to lots of errors since the channel might close BEFORE DELIVERY
    # spawn sender.send_message("From: #{sender.to_s} - with channel", receiver: receiver)
  end
end

users.each do |sender|
  users.each do |receiver|
    # sender.send_message("close")
    spawn sender.send_message("close")
  end
end
#
# # wait for all channels to close
# puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"
# loop do
#   break if users.all?{ |u| u.channel.closed? }
#   Fiber.yield  # give fibers a chance to execute
#   # its interesting to see how long to close by using puts instead of Fiber.yield
#   # puts users.all?{ |u| u.channel.closed? }
# end
# puts "ALL CLEINTS CLOSED? #{ users.all?{ |u| u.channel.closed? } }"

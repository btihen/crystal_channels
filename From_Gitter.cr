# @stnluu_twitter
# an (inaccurate) depiction of what that green thread does is:
#
# make a repo and share code with: @stnluu_twitter & @randiaz95!
# @randiaz95 - cool - I'll do the same (share my current and hopefully improved by @stnluu_twitter - version) at github/btihen - tomorrow.
#
# while !queue.empty
#   queue.each do |w|
#     w.do_work()
#     queue.remove w if w.finished?
#   end
# end

class User
  property ch : Channel(Message)

  def start_listening_to_messages
    spawn do
      loop do
        msg = @ch.receive?
        break if msg.nil? # Channel is closed
        post_message(msg)
      end
    end
  end
end

class Room
  # to ensure that message arrive in the order written use channels!
  # from your loop, you just call - with the above User class
  # two more things
  # - if you have one channel at the room level, make sure the message has a "sender" field that you would skip broadcasting to itself, or upon receiving a message, the user skips post_message for the ones come form themselves. otherwise you'll get an infinite loop.
  # - if your messages are big, use class, not struct. Otherwise the penalty for copying messages between fibers is huge
  users.each_value do |receiver|
    # avoid infinite channel loop!
    next if message.receiver == reciever

    receiver.ch.send(message)
  end


  # this risks loosing the receiver value as only the last element - in some cases
  # users.each_value do |receiver|
  #   spawn do
  #     receiver.post_message( full_message )
  #   end
  #   # Fiber.yield  - not here - if expensive it will cause lots of delays
  # end
  # Fiber.yield

  # when sending to a method this is safer
  # users.each_value do |receiver|
  #   spawn receiver.post_message( full_message )
  # end
  # Fiber.yield
  # or do this (what's behind the scenes)
  # i = 0
  # while i < 10
  #   proc = ->(x : Int32) do
  #     spawn do
  #       puts(x)
  #     end
  #   end
  #   proc.call(i)
  #   i += 1
  # end
  # Fiber.yield

end

# from your loop, you just call receiver.ch.send(full_message), this is just a CPU operation
# the @ch.receive() above will block the spawned fiber, but if there's no message, the thread will just move on to another fiber
# this way, the messages will be processed in the order which this User object received the messages
# hmm - cool. Now channels are starting to make sense as to why I would use them. They are a little like a message mail system. cool - thanks for the sending from the room too.
# hope that helped a bit :)
# interesting...
# for def post_message, I recommend having a "Room" object, or a handful of room objects withtheir own channels and a loop doing the same thing. this prevents each user from needing to keep track of other users
# (and keep the messages from the room in order)

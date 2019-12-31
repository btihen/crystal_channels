# channels

This uses channels back and forth between users and chat rooms.

**Questions**
- how to I stop program AFTER all thread and fibers are finished!

**TODO:**
- **ADD parellism** - each user needs their own separate window / connection (tcp) - then it should be readable. (otherwise messages are all jumbled)

## Installation

**1 thread compile**
crystal build --release src/chat_channels.cr -o ./chat_channels

**compile with parellelism**
crystal build --release -Dpreview_mt  src/chat_channels.cr -o ./chat_channels

## Usage

**run in one big thread**
./chat_channels
or
crystal run src/chat_channels.cr

**run in parrell**
time ./channels  # default workers is 4
time CRYSTAL_WORKERS=2 ./channels
time CRYSTAL_WORKERS=4 ./channels
_(very hard to read -without each user having their own tcp-session / or window) - messages get all jumbled in one output window)_

## Development

thanks to help and clarification from **@stnluu_twitter**

## Contributing

1. Fork it (<https://github.com/your-github-user/channels/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Bill Tihen](https://github.com/your-github-user) - creator and maintainer
- @stnluu_twitter - ideas and clarifications

## Discussion on Crystal Gitter with @stnluu_twitter

I have a question about threads -- if I would like to efficiently send lots of messages to other objects would this approach work or is it too simple (the messages are immutable structs) - I am not sure where the best place to Fiber.yield is:

    users.each_value do |receiver|
      spawn do
        receiver.post_message( full_message )
      end
      # Fiber.yield  - would this be a better location?
    end
    Fiber.yield

also if the receiver objects were to forward this message to more objects in a similar manner (I'm assuming Fiber.yield only affects the Fibers it spawned - not all fibers. If it releases all fibers - what is the correct way to trigger an objects own fibers? I find the examples with sleep not clear to me when dealing with objects forwarding to objects, potentially forwarding to objects.
Thanks in advance for any input.
it depends on what post_message does. is it doing a bunch of IO?
or does each receiver have their own channel and post_message simply sends it over to their channel in memory?
Each user has a method which forwards to its various IO objects (sessions - the sessions do real IO). I thought maybe I should be using channels, but I am not sure how they would help and the best way to manage the channel connections. would I need to build a channel for each object and associate that say in a hash and send the message to the channel without spawning to each object. (Sorry - I'm reasonably confused)
@stnluu_twitter
without knowing more of the problem you’re trying to solve, what you have seems fine. or the alternative is to put the “spawn” inside post_message and do what you need
maybe i’ll have better suggestion if you describe your use-case, rather than nitpicking on a specific implemenation without context :)
you want Fiber.yield OUTside the loop. otherwise it’ll block until each receiver finish doing its things
however, be careful with captured variables (there’s a difference between spawn do .. end and just spawn macro)
God bless Javascript..
https://crystal-lang.org/reference/guides/concurrency.html
read the “Spawning a call” section here
"<th scope='row'>" + i+1 + "</th>" returns table header with 01 11 21 etc. not the sum, lol...
Sorry for another js rant..
does wrapping (i + 1) inside parentheses do the right thing?
yep
@stnluu_twitter - Thanks. I am trying a few mini-projects to understand how to use threads and channels. From the docs where the only thing that happens is sleep - but I am interesting in knowing when to use channels and when not to. When to fiber.yield (thanks for the answer). And when channels are appropriate - what is the best usage pattern. So my mini-experiment is that I am building a fake chat-room that has users - who can 'join' multiple rooms. Each room and each connection has a session that prints (at the moment I am not doing anything special with the sessions - just pretending that they are various tcp connections on various devices - all belonging to the single user.
that is the solution
@btihen Ah! There really isn't a right a wrong way, or any written rules of when you should use a channel and when you shouldn't. In general, if you have all of your input up front, just calling a function is the right thing to do. This function may spawn (i.e. fire and forget) a fiber if you want things running concurrently.
If you need to communicate things between different fibers, for example, you want to get the result or a signal after a spawned fiber completes, this is when message passing, or channels come into play
So for your use case, it really depends on your design and guarantee. I'll list two designs here, with different approaches:
@stnluu_twitter - ah - so using channels is for when a send and response is required to continue for example with a credit card check (it must clear before purchase is allowed) or an authentication must be approved before joining a group would be allowed. the spawn macro for methods looks helpful (cleaner). - ah - so if I am using the spawn block within an iterator - i might be only getting the last value inside the fibers. So the solution is either to use the proc or the spawn macro - otherwise I'm probably not doing what I think with my loop!
kind of
in your case with the credit card check, if you must wait for the result before proceeding, you don't need to spawn a fiber, even if that check involves expensive IO.
fibers are NOT threads
so you're not blocking a thread. if you checkCreditCard function does IO, the underlying OS green thread will switch to other fibers, and come back to it once the IO finishes
the OS green thread does not get blocked, even though your checkCreditCard function takes a long time
the fiber/function is blocked
back to the chatroom use-case:
Ah - so firing a standard IO - is a full OS thread and that just gets skipped while waiting for a response. So a channel wouldn't really help in this case when it is a 'print' job or 'tcp' or something like that.
umm, not quite. let me try again
A fiber on the other hand is blocked until the spawning fiber gives it the go-ahead ?
unless you compile with a special flag, the WHOLE binary only has one OS green thread.
imagine there's a queue. the first thing in the queue is your main fiber.
when you spawn a fiber, another thing gets added to the queue.
Hi! Is there any rails-like parameterize method for string?
an (inaccurate) depiction of what that green thread does is:

while !queue.empty
  queue.each do |w|
    w.do_work()
    queue.remove w if w.finished?
  end
end

@btihen for IO functions, the standard library jsut implement do_work in a way that will just fire the IO call to the OS, and return immediately. the next do_work call will check with the OS and see if the data is ready
does that makes sense?
OK - so if I have an expenseive IO 'print' and a message in memory (which hopefully triggers some expensive activity). If the IO is first, it will just get outsourced to the OS and return to the queue. But from the loop idea - it looks like the message that triggers an expensive calculation would block the main thread while the IO doesn't since it got 'outsourced'
correct. in other words spawn do someVeryIntensiveCPUWork() end will not block your current loop, but then someone else will get delayed if they come after that fiber
@luis_salazar_twitter not that i know of
@btihen there's no magic to this. at the end of the day, some CPU will still need to do your bidding. the only difference is that spawning a fiber lets you defer the work.
@Blacksmoke16 thanks! :D
now, in your example, if post_message is doing IO--aka blocking the fiber that calls it, then maybe spawn post_message is a good option (assuming that's the design you want)
@stnluu_twitter somehow I had the impression that crystal is good at concurrency and parrellism (or at least is designed for that). So the only way for the next job to not get massively delayed would be to send it off to another thread and that isn't the default setup. Basically, I thought crystal could use all (or most of my cpu magically - reducing the blocking happening in the fibers and even when it wasn't on different CPUs it was very good at switching between all tasks in a fast lightweight manner like elixir.
Crystal has concurrency, not parallelism :)
(not unless you compile with the experimental multi thread flag)
read this: https://crystal-lang.org/2019/09/06/parallelism-in-crystal.html

https://crystal-lang.org/reference/guides/concurrency.html

    At the moment of this writing, Crystal has concurrency support but not parallelism: several tasks can be executed, and a bit of time will be spent on each of these, but two code paths are never executed at the same exact time.

@btihen now, back to the chat room example and how/when you want to use channels.
@btihen one subtle side effect of spawn post_message(...), especially if you run in multi thread mode, is the receiver might be getting messages in random order, because fibers are not guaranteed to run in the order they spawn
Ah its still experimental - Ok - I thought it was already mainstream. So in anycase, in my chat-room. spawn post_message is propbably the most approprite. Message delivery timing isn't important - just that it gets delivered. Yes I'm currious about the channel usage. Thanks - you are very helpful!
This is where channels come in
assuming you have a class User somewhere. each user can have their own channel (read: FIFO queue). and each user have something like this:

class User

Ah - yes a randomly ordered chat would be very confusing - cool - now I'm all ears - I've noticed the randomness when spawning

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

from your loop, you just call receiver.ch.send(full_message), this is just a CPU operation
the @ch.receive() above will block the spawned fiber, but if there's no message, the thread will just move on to another fiber
this way, the messages will be processed in the order which this User object received the messages
hmm - cool. Now channels are starting to make sense as to why I would use them. They are a little like a message mail system. cool - thanks for the sending from the room too.
hope that helped a bit :)
interesting...
for def post_message, I recommend having a "Room" object, or a handful of room objects withtheir own channels and a loop doing the same thing. this prevents each user from needing to keep track of other users
(and keep the messages from the room in order)
0.o
@btihen precisely. if you think of each part of your design and its own entity with a mailbox, it's a lot easier to reason about.
Yeah channels are ways to communicate between fibers (and threads, although iirc they're not thread safe yet)
Yeah - a lot - thanks - in particular - I couldn't figure out the benefit of channels - except some theory and usage was unclear while interacting with real objects! all mcy clearer now. I'll go off and see if I can figure out the best way for the user to have multiple sessions associated with the channels and how the
There is a bit overhead with message passing like this, but overall it's pretty negligible
Yeah it's tiny
i'll see if I can copy your notes - and play with it tomorrow. I need to get to bed soon. Thanks so much!
@watzon I thought they were supposed to be thread safe with the -Dmt_preview flag?
@btihen cheers!

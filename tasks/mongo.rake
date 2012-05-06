
namespace :mongo do
  NAME = 'mongod'

  def running?
    out = `ps aux | grep #{NAME} | grep -v "grep #{NAME}"`
    out = out.squeeze(' ').strip
    not out.empty?
  end

  task :start do
    if running?
      puts "Mongo is already running."
    else
      system('mongod run --config /usr/local/Cellar/mongodb/2.0.2-x86_64/mongod.conf &>/dev/null &')
      puts "Mongo started."
    end
  end

  task :stop do
    if running?
      system('killall mongod')
      puts "Mongo stopped."
    else
      puts "Mongo isn't running."
    end
  end

  task :restart => [:stop, :start]
end

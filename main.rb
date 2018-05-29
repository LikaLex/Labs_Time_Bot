# coding: UTF-8
require 'telegram/bot'
require 'dotenv/load'
require 'redis'

TOKEN = ENV['MyTOKEN']


class BaseClass
  attr_accessor :bot

  def initialize(bot, message)
    @redis = Redis.new
    @message = message
    @bot = bot
    @user_id = message.chat.id
    @name = message.from.first_name
  end

  def send_message(text)
    bot.api.send_message(chat_id: @message.chat.id, text: text)
  end


  def valid_date?(date_string)
    date = Date.parse(date_string).to_s
    year, month, day = date.split '-'
    Date.valid_date? year.to_i, month.to_i, day.to_i
    return true
  rescue
    return false
  end


  def time_left(begin_date, end_date)
    today = Date.today
    if end_date > today
      @remainder = (end_date - today).to_i
      @sum_of_days = (end_date - begin_date).to_i
      true
    else
      false
    end
  end

  def calculator(tasks)
    days_per_task = @sum_of_days / tasks
    days_gone = @sum_of_days - @remainder
    @accomplished = days_gone / days_per_task
  end


  def telegram_send_message(text, marker, subjects_numlabs = nil)
    case marker
    when 'reset'
      kb = [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Удаляем', callback_data: 'delete'),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отмена', callback_data: 'cancel')
      ]
    when 'submit_list'
      kb = []
      subjects_hash = @redis.hgetall("#{@user_id}-subject")
      subjects_hash.each do |key, value|
        kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: key, callback_data: key))
      end
    when 'submit_numlabs'
      array_numbers_of_labs = @redis.hget("#{@user_id}-subject-numlab", subjects_numlabs).delete('[,]').split
      kb = []
      array_numbers_of_labs.each do |count|
        kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: count, callback_data: count))
      end
    end
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    @bot.api.send_message(chat_id: @user_id, text: text, reply_markup: markup)
  end



end

class Start < BaseClass
  def run
    send_message("Привет.\n#{Command_list}")
  end
end


Command_list = "Я тебе смогу помочь сдать все лабы, чтобы мамка не ругалась.\n
Вот список того, что я умею:\n
/start - Приветствие и отображение всех доступных команд
/semester - запоминает даты начала и конца семестра
/subject - добавляет предмет и количество лабораторных работ по нему
/status -  выводит твой список лаб, которые тебе предстоит сдать
/submit - Учитывает сдачу лабораторной работы
/reset - Сбрасывает и удаляет все пользовательские данные".freeze

class Semester < BaseClass
  def run
    send_message('Когда начинаем учиться?(Формат: ГГГГ-ММ-ДД)')
    @bot.listen do |message|
      if valid_date?(message.text) == false then send_message(
        "#{@name}, ты неверно ввел дату!")
      else
        @start_date = Date.parse(message.text)

        send_message('Когда надо сдать все лабы?(Формат: ГГГГ-ММ-ДД)')
        @bot.listen do |answer|
          if valid_date?(answer.text) == false then send_message(
            "#{@name}, ты неверно ввел дату!")
          else
            @end_date = Date.parse(answer.text)

            if time_left(@start_date, @end_date) == true then
              @redis.hmset("#{@user_id}-date", "begin", @start_date, "end", @end_date)
            send_message("Понял, на все про все у нас:#{@remainder} дней")
            else
              send_message('Время вышло')
            end
            break
          end
        end
        break
      end
    end
  end
end


class Subject < BaseClass
  def run
    send_message('Какой предмет учим?')
    bot.listen do |answer|
      @task = answer.text
      send_message('Сколько лаб надо сдать?')
      bot.listen do |answer|
        if !/\d+/.match(answer.text) == true then send_message("#{@name}, введи число!")
        else
          send_message('ОК.')
          @redis.hmset("#{@user_id}-subj", @task, answer.text)
          break
        end
      end
      break
    end
  end
end

class Status < BaseClass
  def run
    if @redis.hget("#{@user_id}-date", "begin").nil? then send_message(
      'Сначала введи начало и конец семестров (/semester)')
    else
      day_start = Date.parse(@redis.hget("#{@user_id}-date", "begin"))
      day_end = Date.parse(@redis.hget("#{@user_id}-date", "end"))
      time_left(day_start, day_end)
      send_message("Осталось времени #{@remainder} дней")
      stack = @redis.hgetall("#{@user_id}-subj")
      stack.each do |key, value|
        calculator(value.to_i)
        send_message("#{key} - #{@accomplished} из #{value} предметов должны быть уже сданы")
      end
    end
  end
end


class Reset < BaseClass
  def run
    @redis.del("#{@user_id}-date", "#{@user_id}-subj")
    send_message("#{@name}, Твои данные удалены")
  end
end


class Submit < BaseClass
  def submit_message
    if @redis.hgetall("#{@user_id}-subject") == {}
      send_message("Список пуст.\nДобавить предмет и количество лабораторных работ по нему можно с помощью '/subject'")
    else
      telegram_send_message('Молодец! Какой предмет сдал(а)?', 'submit_list')
    end
  end

  def submit_hundler(input)
    input_submit = input
    if /^[a-zA-Z]+$|^[а-яА-ЯЁё]+$/ =~ input_submit
      @subject_name = input
      if @redis.hget("#{@user_id}-subject-numlab", input).nil?
        num_lab(input_submit)
      elsif @redis.hget("#{@user_id}-subject-numlab", input) == '[]'
        send_message('Ты уже рассчитался по этому предмету!')
      else
        telegram_send_message('Какая лаба?', 'submit_numlabs', input)
      end
    elsif /^\d(\d)*?$/ =~ input_submit
      lab_remove(@subject_name, input)
      send_message('Красавчег!')
    end
  end

  def num_lab(name)
    num = @redis.hget("#{@user_id}-subject", name).to_i
    numlabs = (1..num).to_a
    @redis.hset("#{@user_id}-subject-numlab", name, numlabs.to_s)
    telegram_send_message('Какая лаба?', 'submit_numlabs', name)
  end

  def lab_remove(name, num_labs)
    array_numbers_of_labs = @redis.hget("#{@user_id}-subject-numlab", name).delete('[,]').split
    array_numbers_of_labs.delete(num_labs)
    array_numbers_of_labs_numbers = []
    array_numbers_of_labs.each { |unit| array_numbers_of_labs_numbers.push(unit.to_i) }
    @redis.hset("#{@user_id}-subject-numlab", name, array_numbers_of_labs_numbers.to_s)
  end
end



Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      Start.new(bot, message).run
    when '/semester'
      Semester.new(bot, message).run
    when '/reset'
      Reset.new(bot, message).run
    when '/subject'
      Subject.new(bot, message).run
    when '/status'
      Status.new(bot, message).run
    when '/stop'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Bye, #{message.from.first_name}")
    end
  end
end
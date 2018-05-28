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

end

class Start < BaseClass
  def run
    send_message('Привет. Я тебе смогу помочь сдать все лабы, чтобы мамка не ругалась. Смотри список что я умею:
/semester - запоминает даты начала и конца семестра
/subject - добавляет предмет и количество лабораторных работ по нему
/status - выводит твой список лаб, которые тебе предстоит сдать
/reset - сбрасывает для пользователя все данные.')
  end
end

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
            send_message("Понял, на все про все у нас:#{@remainder}")
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
          break
        end
      end
      break
    end
  end
end




class Reset < BaseClass
  def run
    send_message("#{@name}, Твои данные удалены")
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

    when '/stop'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Bye, #{message.from.first_name}")
    end
  end
end
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

  def sendMessage(text)
    bot.api.sendMessage(chat_id: @message.chat.id, text: text)
  end


  def valid_date?(date_string)
    date = Date.parse(date_string).to_s
    year, month, day = date.split "-"
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

end

class Start < BaseClass
  def run
    sendMessage("Привет. Я тебе смогу помочь сдать все лабы, чтобы мамка не ругалась. Смотри список что я умею:
/semester - запоминает даты начала и конца семестра
/subject - добавляет предмет и количество лабораторных работ по нему
/status - выводит твой список лаб, которые тебе предстоит сдать
/reset - сбрасывает для пользователя все данные.")
  end
end




class Semester < BaseClass
  def first_step
    sendMessage("Когда начинаем учиться?(Формат: ГГГГ-ММ-ДД)")
    @bot.listen do |message|
      if valid_date?(message.text) == false then sendMessage(
        "#{@name}, ты неверно ввел дату!")
      else
        @start_date = Date.parse(message.text)

        sendMessage("Когда заканчиваем учиться?(Формат: ГГГГ-ММ-ДД)")
        @bot.listen do |answer|
          if valid_date?(answer.text) == false then sendMessage(
            "#{@name}, ты неверно ввел дату!")
          else
            @end_date = Date.parse(answer.text)

            if time_left(@start_date, @end_date) == true then
            sendMessage("В запасе дней:#{@remainder}")
            else
              sendMessage("Время вышло")
            end
            break
          end
        end
        break
      end
    end
  end
end



class Reset < BaseClass
  def run
    sendMessage("Твои данные удалены")
  end
end



Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      Start.new(bot, message).run
    when '/semester'
      Semester.new(bot, message).first_step
    when '/reset'
      Reset.new(bot, message).run

    when '/stop'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Bye, #{message.from.first_name}")
    end
  end
end
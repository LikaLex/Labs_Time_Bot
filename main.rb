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
end

class Start < BaseClass
  def run
    sendMessage("/start - Привет. Я тебе смогу помочь сдать все лабы, чтобы мамка не ругалась. Смотри список что я умею:
/semester - запоминает даты начала и конца семестра
/subject - добавляет предмет и количество лабораторных работ по нему
/status - выводит твой список лаб, которые тебе предстоит сдать
/reset - сбрасывает для пользователя все данные.")
  end
end




Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      Start.new(bot, message).run
    when '/stop'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Bye, #{message.from.first_name}")
    end
  end
end
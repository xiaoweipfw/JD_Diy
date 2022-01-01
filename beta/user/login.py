import asyncio
import os

from telethon import TelegramClient, events

from .. import API_HASH, API_ID, BOT, PROXY_START, PROXY_TYPE, connectionType, jdbot, chat_id, CONFIG_DIR
from ..bot.utils import V4

if BOT.get('proxy_user') and BOT['proxy_user'] != "代理的username,有则填写，无则不用动":
    proxy = {
        'proxy_type': BOT['proxy_type'],
        'addr': BOT['proxy_add'],
        'port': BOT['proxy_port'],
        'username': BOT['proxy_user'],
        'password': BOT['proxy_password']}
elif PROXY_TYPE == "MTProxy":
    proxy = (BOT['proxy_add'], BOT['proxy_port'], BOT['proxy_secret'])
else:
    proxy = (BOT['proxy_type'], BOT['proxy_add'], BOT['proxy_port'])
# 开启tg对话
if PROXY_START and BOT.get('noretry') and BOT['noretry']:
    user = TelegramClient(f'{CONFIG_DIR}/user', API_ID, API_HASH, connection=connectionType, proxy=proxy)
elif PROXY_START:
    user = TelegramClient(f'{CONFIG_DIR}/user', API_ID, API_HASH, connection=connectionType, proxy=proxy, connection_retries=None)
elif BOT.get('noretry') and BOT['noretry']:
    user = TelegramClient(f'{CONFIG_DIR}/user', API_ID, API_HASH)
else:
    user = TelegramClient(f'{CONFIG_DIR}/user', API_ID, API_HASH, connection_retries=None)
    
    
def restart():
    text = "if [ -d '/jd' ]; then cd /jd/jbot; pm2 start ecosystem.config.js; cd /jd; pm2 restart jbot; else " \
            "ps -ef | grep 'python3 -m jbot' | grep -v grep | awk '{print $1}' | xargs kill -9 2>/dev/null; " \
            "nohup python3 -m jbot >/ql/log/bot/bot.log 2>&1 & fi "
    os.system(text)
    

@jdbot.on(events.NewMessage(from_users=chat_id, pattern=r'^/rmuser$'))
async def user_login(event):
    try:
        await jdbot.send_message(chat_id, '即将删除user.session')
        os.remove(f'{CONFIG_DIR}/user.session')
        await jdbot.send_message(chat_id, '已经删除user.session\n请重新登录')
        path = "/jd/config/botset.json" if V4 else "/ql/config/botset.json"
        with open(path, "r", encoding="utf-8") as f1:
            botset = f1.read()
        botset = botset.replace('user": "True"', 'user": "False"')
        with open(path, "w", encoding="utf-8") as f2:
            f2.write(botset)
        restart()
    except Exception as e:
        await jdbot.send_message(chat_id, '删除失败\n' + str(e))


@jdbot.on(events.NewMessage(from_users=chat_id, pattern=r'^/login$'))
async def user_login(event):
    try:
        await user.connect()
        async with jdbot.conversation(event.sender_id, timeout=100) as conv:
            msg = await conv.send_message('请输入手机号：\n例如：+8618888888888')
            phone = await conv.get_response()
            print(phone.raw_text)
            await user.send_code_request(phone.raw_text, force_sms=True)
            msg = await conv.send_message('请输入手机验证码:\n例如`code12345code`\n两侧code必须有')
            code = await conv.get_response()
            print(code.raw_text)
            await user.sign_in(phone.raw_text, code.raw_text.replace('code', ''))
        await jdbot.send_message(chat_id, '恭喜您已登录成功！\n自动重启中！')
        path = "/jd/config/botset.json" if V4 else "/ql/config/botset.json"
        with open(path, "r", encoding="utf-8") as f1:
            botset = f1.read()
        botset = botset.replace('user": "False"', 'user": "True"')
        with open(path, "w", encoding="utf-8") as f2:
            f2.write(botset)
        restart()
    except asyncio.exceptions.TimeoutError:
        await jdbot.edit_message(msg, '登录已超时，对话已停止')
    except Exception as e:
        await jdbot.send_message(chat_id, '登录失败\n 再重新登录\n' + str(e))
    finally:
        await user.disconnect()

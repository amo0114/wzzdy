import OpenAI from "openai";
import common from '../../lib/common/common.js'
let groupMessages = []
const model_map = {
    'DS-V3': 'deepseek-ai/DeepSeek-V3',     //可自行将deepseek-ai/DeepSeek-R1或deepseek-ai/DeepSeek-V3修改
    'DS-R1': 'deepseek-ai/DeepSeek-R1'      //如需你比较有钱且需要快速响应，可更改为Pro/deepseek-ai/DeepSeek-R1与Pro/deepseek-ai/DeepSeek-V3，需要使用充值余额，免费余额无法使用
}
let model_type = model_map['DS-V3']
const model_name_map = {
    [model_map['DS-V3']]: 'V3',
    [model_map['DS-R1']]: 'R1'
}
const openai = new OpenAI({
    baseURL: 'https://api.siliconflow.cn/v1',
    apiKey: 'sk-izjtligvfueacvnulinegnoxsuzjwpuxsnvdvzaaeghghsqq'    //在这里填写你的siliconflow-apiKey
});

export class DeepSeek extends plugin {
    constructor() {
        super({
            name: 'deepseek',
            dsc: 'deepseek',
            event: 'message',
            priority: -2000,
            rule: [
                {
                    reg: '^#deepseek结束对话$',
                    fnc: 'reset'
                },
                {
                    reg: '^#deepseek设置上下文长度(.*)$',
                    fnc: 'setMaxLength',
                    permission: 'master'
                },
                {
                    reg: '^#deepseek设置群聊记录长度(.*)$',
                    fnc: 'setHistoryLength',
                    permission: 'master'
                },
                {
                    reg: '^#deepseek设置提示词(.*)$',
                    fnc: 'setPrompt',
                    permission: 'master'
                },
                {
                    reg: '^#deepseek设置温度(.*)$',
                    fnc: 'setTemperature',
                    permission: 'master'
                },
                {
                    reg: '^#更改模型$',
                    fnc: 'switchModel'
                },
                {
                    reg: '^#chat(.*)$',//会匹配任何开头不包含*%#的聊天，可改为'^#chat(.*)$', 更改后仅匹配#chat
                    fnc: 'chat'
                }

            ]
        })
        //redis.get('deepseekJS:model_type').then(res => {
        //if (res) model_type = res})
    }
    async switchModel(e) { // 切换模型逻辑
        model_type = await redis.get('deepseekJS:model_type')
        const isV3 = model_type === model_map['DS-V3']
        model_type = isV3 ? model_map['DS-R1'] : model_map['DS-V3'] // 获取友好名称
        const modelName = model_name_map[model_type]// 发送提示消息
        e.reply(`模型已切换为 ${modelName} 版本\n` +
            `当前特性：\n${isV3 ? '增强复杂指令理解能力' : '优化基础对话流畅度'}`)
        await redis.set('deepseekJS:model_type', model_type)
    }
    async chat(e) {
        let historyLength = await redis.get('deepseekJS:historyLength')
        let maxLength = await redis.get('deepseekJS:maxLength')
        let customPrompt = await redis.get('deepseekJS:prompt')
        let temperature = await redis.get('deepseekJS:temperature')
        historyLength = historyLength >= 0 && historyLength <= 20 ? historyLength : 3
        maxLength = maxLength >= 0 && maxLength <= 10 ? maxLength : 3
        temperature = temperature >= 0 && temperature <= 2 ? temperature : 1
        const msg = e.msg.trim()
        if (!msg) return
        let prompt = [{ role: "system", content: customPrompt ? customPrompt : `你在和多人进行一个对话，你所获得的随机乱码是用来识别用户的，你不能在对话中@或提及用户的id，直接回答问题即可，回答时尽量保持简短，逻辑要通顺，不要对自己的发言做出解释` }]
        let groupChatHistroy = ''
        if (!Array.isArray(groupMessages[e.group_id])) {
            groupMessages[e.group_id] = []
        }
        if (groupMessages[e.group_id].length > 2 * maxLength) {
            groupMessages[e.group_id] = groupMessages[e.group_id].slice(groupMessages[e.group_id].length - 2 * maxLength)
        }
        if (historyLength > 0) {
            groupChatHistroy = await e.bot.pickGroup(e.group_id, true).getChatHistory(0, maxLength)
            prompt[0].content += '以下是群里的近期聊天记录：' + this.formatGroupChatHistory(groupChatHistroy)
        }
        await this.sendChat(
            e,
            [
                ...prompt,
                ...groupMessages[e.group_id]
            ],
            temperature,
            { role: "user", content: `用户名:${e.sender.nickname}，userid:${e.user_id}说：${msg}` }
        )
    }
    async reset(e) {
        groupMessages[e.group_id] = ''
        e.reply('重置对话完毕')
    }
    async sendChat(e, prompt, temperature, msg) {
        let completion
        try {
            completion = await openai.chat.completions.create({
                messages: [
                    ...prompt,
                    msg
                ],
                max_tokens: 2048,
                model: model_type,
                temperature: parseFloat(temperature),
                frequency_penalty: 0.2,
                presence_penalty: 0.2,
                //tools: tools,
                //tool_choice: "auto"
            })
        } catch (error) {
            logger.error(error)
            e.reply('AI对话请求发送失败，请检查日志')
            return true
        }
        let originalRetMsg = completion.choices[0].message.content
        originalRetMsg = originalRetMsg.replace(/<think>[\s\S]*?<\/think>/g, '');
        let matches = await this.dealMessage(e, originalRetMsg)
        //matches.push(`\ntoken消耗:${JSON.stringify(completion.usage)}`)
        e.reply(matches)
        groupMessages[e.group_id].push(msg)
        groupMessages[e.group_id].push({ 'role': 'assistant', 'content': completion.choices[0].message.content })

    }
    async setMaxLength(e) {
        let length = e.msg.replace('#deepseek设置上下文长度', '').trim()
        redis.set('deepseekJS:maxLength', length)
        e.reply('设置成功')
    }
    async setHistoryLength(e) {
        let length = e.msg.replace('#deepseek设置群聊记录长度', '').trim()
        redis.set('deepseekJS:historyLength', length)
        e.reply('设置成功')
    }
    async setPrompt(e) {
        let prompt = e.msg.replace('#deepseek设置提示词', '').trim()
        redis.set('deepseekJS:prompt', prompt)
        e.reply('设置成功')
    }
    async setTemperature(e) {
        let temperature = e.msg.replace('#deepseek设置温度', '').trim()
        redis.set('deepseekJS:temperature', temperature)
        e.reply('设置成功')
    }
    async dealMessage(e, originalRetMsg) {
        let atRegex = /(at:|@)([a-zA-Z0-9]+)|\[CQ:at,qq=(\d+)\]/g
        let matches = []
        let match
        let lastIndex = 0
        while ((match = atRegex.exec(originalRetMsg)) !== null) {
            if (lastIndex !== match.index) {
                matches.push(originalRetMsg.slice(lastIndex, match.index))
            }
            let userId = match[2] || match[3]
            let nickname = e.group?.pickMember(parseInt(userId)).nickname
            if (nickname != undefined) {
                matches.push(segment.at(userId, nickname))
            }
            lastIndex = atRegex.lastIndex
        }
        if (lastIndex < originalRetMsg.length) {
            matches.push(originalRetMsg.slice(lastIndex))
        }
        return matches
    }
    formatGroupChatHistory(groupChatHistory) {
        const regex = /\[CQ:image(.*?)\]/g
        return groupChatHistory.map((chat, index) => {
            const { sender, raw_message } = chat
            const nickname = sender.nickname || "未知用户"
            const userId = sender.user_id
            return `${index + 1}. 用户名: ${nickname}，userid: ${userId} 说：${raw_message.replace(regex, "[图片]")}\n`
        })
    }
}

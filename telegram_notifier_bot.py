#!/usr/bin/env python3
"""
Simple Telegram notification bot with HTTP endpoint.

Users can register topics via Telegram and get UUIDs.
External services can POST to /<uuid> to send notifications.
"""

import asyncio
import json
import logging
import os
import sqlite3
import uuid
from typing import Dict, Optional, List

import aiohttp
from aiohttp import web
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)


class TopicDatabase:
    def __init__(self, db_path: str = "telegram_topics.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize the SQLite database and create tables"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS topics (
                    uuid TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    topic_name TEXT NOT NULL,
                    chat_id INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create index for faster lookups
            cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_user_id ON topics(user_id)
            ''')
            
            conn.commit()
            logger.info(f"Database initialized at {self.db_path}")
        finally:
            conn.close()
    
    def add_topic(self, topic_uuid: str, user_id: int, topic_name: str, chat_id: int) -> bool:
        """Add a new topic to the database"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO topics (uuid, user_id, topic_name, chat_id)
                VALUES (?, ?, ?, ?)
            ''', (topic_uuid, user_id, topic_name, chat_id))
            conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False  # UUID already exists
        finally:
            conn.close()
    
    def get_topic(self, topic_uuid: str) -> Optional[Dict]:
        """Get a topic by UUID"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT uuid, user_id, topic_name, chat_id, created_at
                FROM topics WHERE uuid = ?
            ''', (topic_uuid,))
            row = cursor.fetchone()
            if row:
                return {
                    "uuid": row[0],
                    "user_id": row[1],
                    "topic_name": row[2],
                    "chat_id": row[3],
                    "created_at": row[4]
                }
            return None
        finally:
            conn.close()
    
    def get_user_topics(self, user_id: int) -> List[Dict]:
        """Get all topics for a user"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT uuid, user_id, topic_name, chat_id, created_at
                FROM topics WHERE user_id = ?
                ORDER BY created_at DESC
            ''', (user_id,))
            rows = cursor.fetchall()
            return [
                {
                    "uuid": row[0],
                    "user_id": row[1],
                    "topic_name": row[2],
                    "chat_id": row[3],
                    "created_at": row[4]
                }
                for row in rows
            ]
        finally:
            conn.close()
    
    def find_topic_by_name(self, user_id: int, topic_name: str) -> Optional[Dict]:
        """Find a topic by user ID and topic name"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT uuid, user_id, topic_name, chat_id, created_at
                FROM topics WHERE user_id = ? AND topic_name = ?
            ''', (user_id, topic_name))
            row = cursor.fetchone()
            if row:
                return {
                    "uuid": row[0],
                    "user_id": row[1],
                    "topic_name": row[2],
                    "chat_id": row[3],
                    "created_at": row[4]
                }
            return None
        finally:
            conn.close()
    
    def delete_topic(self, user_id: int, topic_name: str) -> bool:
        """Delete a topic by user ID and topic name"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute('''
                DELETE FROM topics WHERE user_id = ? AND topic_name = ?
            ''', (user_id, topic_name))
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()


# Global database instance
db = TopicDatabase()


class NotifierBot:
    def __init__(self, bot_token: str, webhook_port: int = 8080):
        self.bot_token = bot_token
        self.webhook_port = webhook_port
        self.app = Application.builder().token(bot_token).build()
        
        # Register command handlers
        self.app.add_handler(CommandHandler("start", self.start_command))
        self.app.add_handler(CommandHandler("help", self.help_command))
        self.app.add_handler(CommandHandler("register", self.register_command))
        self.app.add_handler(CommandHandler("unregister", self.unregister_command))
        self.app.add_handler(CommandHandler("list", self.list_topics_command))

    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /start command"""
        welcome_msg = (
            "🤖 Welcome to the Notification Bot!\n\n"
            "Commands:\n"
            "• /register <topic_name> - Register a new topic and get a UUID\n"
            "• /unregister <topic_name> - Unregister a topic\n"
            "• /list - List your registered topics\n"
            "• /help - Show this help message\n\n"
            "After registering a topic, you'll get a UUID that others can use to send you notifications via HTTP POST."
        )
        await update.message.reply_text(welcome_msg)

    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /help command"""
        await self.start_command(update, context)

    async def register_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /register <topic_name> command"""
        if not context.args:
            await update.message.reply_text("Please provide a topic name: /register <topic_name>")
            return

        topic_name = " ".join(context.args)
        user_id = update.effective_user.id
        chat_id = update.effective_chat.id

        # Check if user already has this topic
        existing_topic = db.find_topic_by_name(user_id, topic_name)
        if existing_topic:
            await update.message.reply_text(f"❌ Topic '{topic_name}' already exists!")
            return

        # Generate new UUID and register topic
        topic_uuid = str(uuid.uuid4())
        
        if db.add_topic(topic_uuid, user_id, topic_name, chat_id):
            await update.message.reply_text(
                f"✅ Topic '{topic_name}' registered!\n\n"
                f"🔗 Webhook URL: `{topic_uuid}`\n\n"
                f"Others can now POST to: `http://your-server:8080/{topic_uuid}`",
                parse_mode='Markdown'
            )
        else:
            await update.message.reply_text("❌ Failed to register topic. Please try again.")

    async def unregister_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /unregister <topic_name> command"""
        if not context.args:
            await update.message.reply_text("Please provide a topic name: /unregister <topic_name>")
            return

        topic_name = " ".join(context.args)
        user_id = update.effective_user.id

        # Delete topic from database
        if db.delete_topic(user_id, topic_name):
            await update.message.reply_text(f"✅ Topic '{topic_name}' unregistered!")
        else:
            await update.message.reply_text(f"❌ Topic '{topic_name}' not found!")

    async def list_topics_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /list command"""
        user_id = update.effective_user.id
        user_topics = db.get_user_topics(user_id)

        if not user_topics:
            await update.message.reply_text("📋 You have no registered topics.")
            return

        topic_list = []
        for topic in user_topics:
            topic_list.append(f"• {topic['topic_name']}: `{topic['uuid']}`")

        message = "📋 Your registered topics:\n\n" + "\n".join(topic_list)
        await update.message.reply_text(message, parse_mode='Markdown')


async def webhook_handler(request):
    """Handle HTTP POST requests to /<uuid>"""
    topic_uuid = request.match_info.get('uuid')
    
    # Get topic from database
    topic_info = db.get_topic(topic_uuid)
    if not topic_info:
        return web.Response(status=404, text="Topic not found")

    try:
        # Get message from request body
        if request.content_type == 'application/json':
            data = await request.json()
            message = data.get('message', str(data))
        else:
            message = await request.text()

        if not message:
            return web.Response(status=400, text="No message provided")

        # Get topic info
        topic_name = topic_info['topic_name']
        chat_id = topic_info['chat_id']

        # Send notification via Telegram
        bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
        telegram_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        
        notification_text = f"🔔 **{topic_name}**\n\n{message}"
        
        async with aiohttp.ClientSession() as session:
            payload = {
                'chat_id': chat_id,
                'text': notification_text,
                'parse_mode': 'Markdown'
            }
            async with session.post(telegram_url, json=payload) as resp:
                if resp.status == 200:
                    return web.Response(status=200, text="Notification sent")
                else:
                    logger.error(f"Failed to send Telegram message: {resp.status}")
                    return web.Response(status=500, text="Failed to send notification")

    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return web.Response(status=500, text="Internal server error")


async def create_webhook_app():
    """Create the HTTP webhook application"""
    app = web.Application()
    app.router.add_post('/{uuid}', webhook_handler)
    
    # Health check endpoint
    async def health_check(request):
        return web.Response(text="OK")
    
    app.router.add_get('/health', health_check)
    return app


async def main():
    """Main function to run both bot and webhook server"""
    bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
    if not bot_token:
        logger.error("TELEGRAM_BOT_TOKEN environment variable is required")
        return

    webhook_port = int(os.getenv('WEBHOOK_PORT', '8080'))

    # Initialize bot
    notifier_bot = NotifierBot(bot_token, webhook_port)
    
    # Start webhook server
    webhook_app = await create_webhook_app()
    runner = web.AppRunner(webhook_app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', webhook_port)
    await site.start()
    
    logger.info(f"Webhook server started on port {webhook_port}")

    # Initialize and start the bot manually to avoid run_polling's event loop issues
    await notifier_bot.app.initialize()
    await notifier_bot.app.start()
    
    logger.info("Starting Telegram bot...")
    await notifier_bot.app.updater.start_polling(drop_pending_updates=True)
    
    try:
        # Keep the program running
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    finally:
        await notifier_bot.app.updater.stop()
        await notifier_bot.app.stop()
        await notifier_bot.app.shutdown()
        await runner.cleanup()


if __name__ == '__main__':
    asyncio.run(main())
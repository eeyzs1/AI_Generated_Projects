from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from models.room import Room, room_members
from models.message import Message
from models.user import User
from schemas.room import RoomCreate, RoomAddMember
from schemas.message import MessageCreate

# 创建聊天室
async def create_room(room_data: RoomCreate, user_id: int, db: AsyncSession) -> Room:
    # 创建房间
    db_room = Room(
        name=room_data.name,
        creator_id=user_id
    )
    db.add(db_room)
    await db.commit()
    await db.refresh(db_room)
    # 将创建者加入房间
    await add_room_member(RoomAddMember(room_id=db_room.id, user_id=user_id), db)
    return db_room

# 添加房间成员
async def add_room_member(member_data: RoomAddMember, db: AsyncSession) -> Room:
    # 检查房间是否存在
    result = await db.execute(select(Room).where(Room.id == member_data.room_id))
    room = result.scalars().first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="房间不存在"
        )
    # 检查用户是否存在
    result = await db.execute(select(User).where(User.id == member_data.user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    # 检查用户是否已在房间
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == member_data.room_id,
            room_members.c.user_id == member_data.user_id
        )
    )
    if result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户已在房间中"
        )
    # 添加成员
    await db.execute(
        room_members.insert().values(
            room_id=member_data.room_id,
            user_id=member_data.user_id
        )
    )
    await db.commit()
    # 刷新房间数据
    await db.refresh(room)
    return room

# 获取用户加入的所有房间
async def get_user_rooms(user_id: int, db: AsyncSession) -> list[Room]:
    result = await db.execute(
        select(Room)
        .join(room_members)
        .where(room_members.c.user_id == user_id)
        .options(selectinload(Room.members))
    )
    return result.scalars().all()

# 发送消息
async def send_message(message_data: MessageCreate, user_id: int, db: AsyncSession) -> Message:
    # 检查房间是否存在
    result = await db.execute(select(Room).where(Room.id == message_data.room_id))
    room = result.scalars().first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="房间不存在"
        )
    # 检查用户是否在房间中
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == message_data.room_id,
            room_members.c.user_id == user_id
        )
    )
    if not result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="你不是该房间成员"
        )
    # 创建消息
    db_message = Message(
        sender_id=user_id,
        room_id=message_data.room_id,
        content=message_data.content
    )
    db.add(db_message)
    await db.commit()
    await db.refresh(db_message)
    # 关联发送者信息
    await db.refresh(db_message, ["sender"])
    return db_message

# 获取房间消息记录
async def get_room_messages(room_id: int, user_id: int, db: AsyncSession) -> list[Message]:
    # 检查用户是否在房间中
    result = await db.execute(
        select(room_members).where(
            room_members.c.room_id == room_id,
            room_members.c.user_id == user_id
        )
    )
    if not result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="你不是该房间成员"
        )
    # 查询消息
    result = await db.execute(
        select(Message)
        .where(Message.room_id == room_id)
        .order_by(Message.created_at)
        .options(selectinload(Message.sender))
    )
    return result.scalars().all()

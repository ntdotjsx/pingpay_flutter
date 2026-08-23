import { db } from "../db";
import { billItems, bills } from "../db/schema";
import { eq, or } from "drizzle-orm";
import type { RealtimeEvent, RealtimeEventType, RealtimeSocket } from "./realtime.types";
import { createRealtimeEvent } from "./realtime.types";

export class RealtimeService {
  private userSockets = new Map<string, Set<RealtimeSocket>>();

  connect(userId: string, socket: RealtimeSocket) {
    const sockets = this.userSockets.get(userId) ?? new Set<RealtimeSocket>();
    sockets.add(socket);
    this.userSockets.set(userId, sockets);

    console.log(`[Realtime] User connected userId=${userId} connections=${sockets.size}`);
    this.sendToSocket(socket, createRealtimeEvent("connection.ready", { userId }));
  }

  disconnect(userId: string, socket: RealtimeSocket) {
    const sockets = this.userSockets.get(userId);
    if (!sockets) return;

    sockets.delete(socket);
    if (sockets.size === 0) {
      this.userSockets.delete(userId);
    }

    console.log(`[Realtime] User disconnected userId=${userId} remaining=${sockets.size}`);
  }

  sendToUser(userId: string, event: RealtimeEvent) {
    const sockets = this.userSockets.get(userId);
    if (!sockets || sockets.size === 0) return 0;

    let sent = 0;
    for (const socket of sockets) {
      if (this.sendToSocket(socket, event)) sent += 1;
    }
    return sent;
  }

  sendToUsers(userIds: string[], event: RealtimeEvent) {
    const uniqueIds = [...new Set(userIds.filter(Boolean))];
    let sent = 0;
    for (const userId of uniqueIds) {
      sent += this.sendToUser(userId, event);
    }
    console.log(`[Realtime] Event sent type=${event.type} recipients=${uniqueIds.length} sockets=${sent}`);
    return sent;
  }

  async sendToBill(billId: string, event: RealtimeEvent) {
    const userIds = await this.getBillMemberUserIds(billId);
    return this.sendToUsers(userIds, event);
  }

  broadcast(event: RealtimeEvent) {
    return this.sendToUsers([...this.userSockets.keys()], event);
  }

  makeEvent<TData = Record<string, unknown>>(
    type: RealtimeEventType,
    data: TData,
    options: { resourceId?: string; version?: number; eventId?: string } = {}
  ) {
    return createRealtimeEvent(type, data, options);
  }

  async getBillMemberUserIds(billId: string) {
    if (!db?.query?.bills?.findFirst) return [];
    try {
      const bill = await db.query.bills.findFirst({
        where: eq(bills.id, billId),
        with: { items: true },
      });

      if (!bill) return [];
      return [...new Set([bill.ownerId, ...bill.items.map((item: any) => item.debtorId)])];
    } catch {
      return [];
    }
  }

  async getBillsForUser(userId: string) {
    return await db
      .select({ billId: bills.id })
      .from(bills)
      .leftJoin(billItems, eq(billItems.billId, bills.id))
      .where(or(eq(bills.ownerId, userId), eq(billItems.debtorId, userId)));
  }

  private sendToSocket(socket: RealtimeSocket, event: RealtimeEvent) {
    try {
      socket.send(JSON.stringify(event));
      return true;
    } catch (error) {
      console.error(`[Realtime] Failed to send event type=${event.type}`, error);
      return false;
    }
  }
}

export const realtimeService = new RealtimeService();

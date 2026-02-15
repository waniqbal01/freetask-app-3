import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
    const email = 'waniqbal@gmail.com';
    const newPassword = 'Password123!';
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    console.log(`Resetting password for ${email}...`);

    try {
        const user = await prisma.user.update({
            where: { email },
            data: { password: hashedPassword },
        });
        console.log(`Password reset successful for user ID: ${user.id}`);
    } catch (e: any) {
        console.error('Failed to reset password:', e.message);
    } finally {
        await prisma.$disconnect();
    }
}

main();

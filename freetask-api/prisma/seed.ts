import { PrismaClient, UserRole, JobStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function createUser(email: string, name: string, role: UserRole) {
  const password = await bcrypt.hash('password123', 10);

  return prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      name,
      password,
      role,
    },
  });
}

async function main() {
  console.log('🌱 Seeding demo data...');

  const [client, freelancer, admin] = await Promise.all([
    createUser('client@test.com', 'Demo Client', UserRole.CLIENT),
    createUser('freelancer@test.com', 'Demo Freelancer', UserRole.FREELANCER),
    createUser('admin@test.com', 'Demo Admin', UserRole.ADMIN),
  ]);

  console.log('✅ Demo users ready:', {
    client: client.email,
    freelancer: freelancer.email,
    admin: admin.email,
  });

  const logoDesign = await prisma.service.create({
    data: {
      title: 'Logo Design Pro',
      description: 'Reka bentuk logo moden dan minimalis untuk bisnes anda.',
      price: 250,
      category: 'Design',
      deliveryDays: 3,
      freelancerId: freelancer.id,
    },
  });

  const landingPage = await prisma.service.create({
    data: {
      title: 'Landing Page Next.js',
      description: 'Bina landing page pantas dengan SEO mesra.',
      price: 480,
      category: 'Web Development',
      deliveryDays: 5,
      freelancerId: freelancer.id,
    },
  });

  const socialKit = await prisma.service.create({
    data: {
      title: 'Social Media Kit',
      description: '10 visual media sosial beserta templat boleh sunting.',
      price: 180,
      category: 'Marketing',
      deliveryDays: 4,
      freelancerId: freelancer.id,
    },
  });

  console.log('✅ Demo services created');

  const jobPending = await prisma.job.create({
    data: {
      title: 'Tempah Logo Baharu',
      description: 'Mahukan logo ringkas dengan warna biru.',
      amount: 250,
      status: JobStatus.PENDING,
      serviceId: logoDesign.id,
      clientId: client.id,
      freelancerId: freelancer.id,
      histories: {
        create: [
          {
            actorId: client.id,
            action: 'CREATED',
            message: 'Client membuat tempahan logo baharu.',
          },
        ],
      },
    },
    include: { histories: true },
  });

  const jobInProgress = await prisma.job.create({
    data: {
      title: 'Sediakan Landing Page',
      description: 'Landing page produk SaaS ringkas.',
      amount: 480,
      status: JobStatus.IN_PROGRESS,
      serviceId: landingPage.id,
      clientId: client.id,
      freelancerId: freelancer.id,
      histories: {
        create: [
          {
            actorId: client.id,
            action: 'CREATED',
            message: 'Job diminta oleh client.',
          },
          {
            actorId: client.id,
            action: 'ACCEPTED',
            message: 'Client menerima tawaran freelancer.',
          },
          {
            actorId: freelancer.id,
            action: 'STARTED',
            message: 'Freelancer memulakan kerja.',
          },
        ],
      },
    },
    include: { histories: true },
  });

  const jobCompleted = await prisma.job.create({
    data: {
      title: 'Pakej Visual Media Sosial',
      description: 'Set visual lengkap untuk kempen minggu hadapan.',
      amount: 180,
      status: JobStatus.COMPLETED,
      serviceId: socialKit.id,
      clientId: client.id,
      freelancerId: freelancer.id,
      histories: {
        create: [
          {
            actorId: client.id,
            action: 'CREATED',
            message: 'Job dimulakan oleh client.',
          },
          {
            actorId: client.id,
            action: 'ACCEPTED',
            message: 'Client mengesahkan untuk diteruskan.',
          },
          {
            actorId: freelancer.id,
            action: 'STARTED',
            message: 'Freelancer mula menyiapkan bahan.',
          },
          {
            actorId: freelancer.id,
            action: 'DELIVERED',
            message: 'Draf awal dihantar kepada client.',
          },
          {
            actorId: client.id,
            action: 'COMPLETED',
            message: 'Client menandakan job sebagai selesai.',
          },
        ],
      },
    },
    include: { histories: true },
  });

  await prisma.chatMessage.createMany({
    data: [
      {
        jobId: jobInProgress.id,
        senderId: client.id,
        content: 'Hai, boleh kongsi wireframe awal?',
      },
      {
        jobId: jobInProgress.id,
        senderId: freelancer.id,
        content: 'Baik, saya akan hantar draft hari ini.',
      },
      {
        jobId: jobInProgress.id,
        senderId: client.id,
        content: 'Terima kasih! Saya tunggu.',
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: freelancer.id,
        type: 'job',
        title: 'Job baharu menunggu tindakan',
        body: `Job #${jobPending.id} menunggu respon anda.`,
      },
      {
        userId: client.id,
        type: 'chat',
        title: 'Pesanan baharu',
        body: 'Freelancer telah membalas chat anda.',
        metadata: { jobId: jobInProgress.id },
      },
      {
        userId: client.id,
        type: 'job',
        title: 'Job siap',
        body: `Job #${jobCompleted.id} ditandakan lengkap.`,
        isRead: true,
      },
    ],
  });

  console.log('✨ Seeding siap. Akaun demo tersedia.');
}

main()
  .catch((error) => {
    console.error('Seed gagal:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

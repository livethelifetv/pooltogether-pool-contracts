#!/usr/bin/env node
const commander = require('commander');
const chalk = require('chalk')
const { Project } = require('@pooltogether/oz-migrate')
const { runShell } = require('./runShell')
const { deploy1820 } = require('deploy-eip-1820')

const { buildContext } = require('oz-console')

const program = new commander.Command()
program.description('Deploys the PoolTogether smart contracts')
program.option('-n --network [network]', 'configure OpenZeppelin network', 'kovan')
program.option('-a --address [address]', 'configures the address to deploy from', process.env.ADMIN_ADDRESS)
program.option('-v --verbose', 'adds verbosity', () => true)

program
  .command('migrate')
  .action(async () => {
    console.log(chalk.dim(`Starting deployment to ${program.network}....`))

    let context = await buildContext({ network: program.network, address: program.address })

    const project = new Project('.oz-migrate')
    const migration = await project.migrationForNetwork(context.networkConfig.network)

    runShell(`oz session --network ${program.network} --from ${program.address} --expires 3600 --timeout 600 --blockTimeout 50`)

    let flags = '-s'
    if (program.verbose) {
      flags = '-v'
    }

    await migration.migrate(2, async () => {
      if (program.network == 'local') {
        console.log(chalk.dim('Deploying ERC1820 Registry...'))
        await deploy1820(context.signer)        
      }
    })

    await migration.migrate(5, async () => {
      if (program.network == 'local') {
        runShell(`oz deploy -n ${program.network} -k regular Forwarder`)
      }
    })

    await migration.migrate(7, async () => {
      if (program.network == 'local') {
        runShell(`oz deploy -n ${program.network} -k regular MockGovernor`)
      }
    })

    let trustedForwarder, governor
    if (program.network == 'kovan') {
      trustedForwarder = '0x6453D37248Ab2C16eBd1A8f782a2CBC65860E60B'
      governor = '0x2f935900D89b0815256a3f2c4c69e1a0230b5860'
    } else if (program.network == 'ropsten') {
      trustedForwarder = '0xcC87aa60a6457D9606995C4E7E9c38A2b627Da88'
      governor = '0xD215CF8D8bC151414A9c5c145fE219E746E5cE80'
    } else {
      context = await buildContext({ network: program.network, address: program.address })
      trustedForwarder = context.networkFile.data.proxies['PoolTogether3/Forwarder'][0].address
      governor = context.networkFile.data.proxies['PoolTogether3/MockGovernor'][0].address
    }

    await migration.migrate(10, async () => {
      runShell(`oz create CompoundPeriodicPrizePoolFactory --force ${flags} --init initialize`)
    })

    await migration.migrate(15, async () => {
      runShell(`oz create TicketFactory --force ${flags} --init initialize`)
    })

    await migration.migrate(20, async () => {
      runShell(`oz create ControlledTokenFactory --force ${flags} --init initialize`)
    })

    await migration.migrate(25, async () => {
      runShell(`oz create SingleRandomWinnerPrizeStrategyFactory --force ${flags} --init initialize`)
    })

    await migration.migrate(30, async () => {
      runShell(`oz create RNGBlockhash --force ${flags}`)
    })

    context = await buildContext({ network: program.network, address: program.address })
    const {
      CompoundPeriodicPrizePoolFactory,
      TicketFactory,
      ControlledTokenFactory,
      SingleRandomWinnerPrizeStrategyFactory,
      RNGBlockhash
    } = context.contracts

    await migration.migrate(35, async () => {
      runShell(`oz create PrizePoolBuilder --force ${flags} --init initialize --args ${governor},${CompoundPeriodicPrizePoolFactory.address},${TicketFactory.address},${ControlledTokenFactory.address},${RNGBlockhash.address},${trustedForwarder}`)
    })

    context = await buildContext({ network: program.network, address: program.address })
    const {
      PrizePoolBuilder,
    } = context.contracts

    await migration.migrate(40, async () => {
      runShell(`oz create SingleRandomWinnerPrizePoolBuilder --force ${flags} --init initialize --args ${PrizePoolBuilder.address},${SingleRandomWinnerPrizeStrategyFactory.address}`)
    })

    console.log(chalk.green(`Completed deployment.`))
    process.exit(0)
  })

program.parse(process.argv)